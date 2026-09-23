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
# Output (stdout): [{"pr": 272, "state": "success", "description": "..."}]
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

PRS=""
if [ -n "$COMMITS" ]; then
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    PRS+=$(gh api "repos/$REPO/commits/$sha/pulls" --jq '.[].number')$'\n'
  done <<<"$COMMITS"
fi

# `sort -u` over an empty string still yields one empty line; the guard below
# drops it rather than looking up PR "".
RECORDS=""
while IFS= read -r pr; do
  [ -n "$pr" ] || continue
  head_sha=$(gh api "repos/$REPO/pulls/$pr" --jq '.head.sha')
  # The combined-status endpoint returns only the newest status per context,
  # which is the one the gate last wrote for that head.
  status=$(gh api "repos/$REPO/commits/$head_sha/status" \
    --jq "[.statuses[] | select(.context == \"$CONTEXT\")] | .[0] // empty")
  if [ -n "$status" ]; then
    record=$(jq -c --argjson pr "$pr" '{pr: $pr, state: .state, description: .description}' <<<"$status")
  else
    # No status at all means the gate never ran on this PR, so nothing is known
    # about whether it was breaking. Report it rather than dropping it: a silent
    # omission would let one PR's signoff authorize a release containing another
    # PR the gate never saw.
    record=$(jq -nc --argjson pr "$pr" '{pr: $pr, state: "missing", description: null}')
  fi
  RECORDS+="$record"$'\n'
done <<<"$(sort -u <<<"$PRS")"

jq -s -c '.' <<<"$RECORDS"
