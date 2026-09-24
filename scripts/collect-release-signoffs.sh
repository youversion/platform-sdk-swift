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

COMMITS=$(gh api --paginate "repos/$REPO/compare/$CURRENT_TAG...$HEAD_REF" --jq '.commits[].sha')

# `commits/<sha>/pulls` returns whole PR objects, so take the head SHA from the
# same response rather than spending a second round trip per PR to fetch it.
PRS=""
if [ -n "$COMMITS" ]; then
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    PRS+=$(gh api "repos/$REPO/commits/$sha/pulls" --jq '.[] | "\(.number) \(.head.sha)"')$'\n'
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

jq -s -c '.' <<<"$RECORDS"
