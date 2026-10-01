#!/bin/bash
#
# Emit the `major-release-signoff` statuses for every PR merged since a tag, as
# the JSON array scripts/release-check-signoff.mjs reads on stdin.
#
# Gathering lives here rather than inline in release.yml so the decision script
# stays pure and testable, and so this half can be run by hand before dispatching
# a release.
#
# Usage:
#   collect-release-signoffs.sh <owner/repo> <current-tag> [<head-ref>]
#
# Output (stdout):
#   [{"pr": 272, "state": "success", "description": "...",
#     "creator": "github-actions[bot]", "creator_type": "Bot"}]
#
# The gate writes its status to the PR *head* SHA, which a squash merge does not
# preserve, so the status cannot be read off the commit on main. Resolve each
# released commit back to its PR and read the status there.

set -euo pipefail

REPO="${1:?usage: $0 <owner/repo> <current-tag> [<head-ref>]}"
CURRENT_TAG="${2:?missing current-tag}"
HEAD_REF="${3:-HEAD}"

CONTEXT="major-release-signoff"

# The compare response already carries author and subject, so classifying a
# commit costs no extra request. `--paginate` matters: the endpoint caps its
# commits array at 250 and a longer range would silently lose the rest.
COMMITS=$(gh api --paginate "repos/$REPO/compare/$CURRENT_TAG...$HEAD_REF" \
  --jq '.commits[] | "\(.sha)\t\(.commit.author.name)\t\(.commit.message | split("\n")[0])"')

# The release process pushes its own commits straight to main over the deploy
# key, so those legitimately have no pull request. Anything else without one
# reached main without the gate ever seeing it, and has to be reported rather
# than passed over. This is not hypothetical: a `feat:` landed directly on main
# between 5.3.0 and 5.4.0.
#
# Author and subject together, because release.sh sets both. Neither is a
# security boundary, since anyone able to push directly can also set them; the
# point is to let the release's own commits through without hiding a real one.
RELEASE_AUTHOR="github-actions[bot][release]"

# `commits/<sha>/pulls` returns whole PR objects, so take the head SHA from the
# same response rather than spending a second round trip per PR to fetch it.
PRS=""
UNREVIEWED=""
if [ -n "$COMMITS" ]; then
  while IFS=$'\t' read -r sha author subject; do
    [ -n "$sha" ] || continue
    found=$(gh api "repos/$REPO/commits/$sha/pulls" --jq '.[] | "\(.number) \(.head.sha)"')
    if [ -n "$found" ]; then
      PRS+="$found"$'\n'
      continue
    fi
    if [ "$author" = "$RELEASE_AUTHOR" ] && [[ "$subject" == chore\(release\):* ]]; then
      continue
    fi
    UNREVIEWED+=$(jq -nc --arg sha "${sha:0:9}" --arg subject "$subject" \
      '{pr: null, commit: $sha, subject: $subject, state: "unreviewed",
        description: null, creator: null, creator_type: null}')$'\n'
  done <<<"$COMMITS"
fi

# `sort -u` over an empty string still yields one empty line; the guard below
# drops it rather than looking up PR "".
RECORDS=""
while IFS=' ' read -r pr head_sha; do
  [ -n "$pr" ] || continue
  # The per-status list, not the combined `/status` endpoint: the combined one
  # omits `creator`, and who posted the status is the only thing separating a
  # gate-produced signoff from one any repo writer can POST by hand. The list is
  # newest-first, so the first match is the status the gate last wrote.
  status=$(gh api "repos/$REPO/commits/$head_sha/statuses" --paginate \
    --jq "[.[] | select(.context == \"$CONTEXT\")] | .[0] // empty")
  if [ -n "$status" ]; then
    record=$(jq -c --argjson pr "$pr" \
      '{pr: $pr, state: .state, description: .description, creator: .creator.login, creator_type: .creator.type}' \
      <<<"$status")
  else
    # No status at all means the gate never ran on this PR, so nothing is known
    # about whether it was breaking. Report it rather than dropping it: a silent
    # omission would let one PR's signoff authorize a release containing another
    # PR the gate never saw.
    record=$(jq -nc --argjson pr "$pr" \
      '{pr: $pr, state: "missing", description: null, creator: null, creator_type: null}')
  fi
  RECORDS+="$record"$'\n'
done <<<"$(sort -u <<<"$PRS")"

jq -s -c '.' <<<"$RECORDS$UNREVIEWED"
