#!/bin/bash
#
# Locate the api-additions-signoff marker comment on a PR and parse the
# detection state stored on its first line. Used by
# .github/workflows/api-additions-signoff-gate.yml on both workflow_run and
# issue_comment events so the marker format is read and written through
# exactly one place.
#
# Marker line format (first line of the bot comment):
#   <!-- api-additions-signoff head=<sha> hash=<12-hex> count=<n> tooling=<0|1> -->
#
# Usage:
#   find-api-additions-comment.sh <owner/repo> <pr-number>
#
# Prints GITHUB_OUTPUT-style lines to stdout (empty values when no marker
# comment exists):
#   comment_id=<id>
#   stored_head=<sha>
#   stored_hash=<hash>
#   stored_count=<n>
#   stored_tooling=<0|1>
#
# Only comments *authored by github-actions[bot]* and *starting with* the
# marker qualify — a PR participant quoting the marker mid-comment must not
# be able to spoof the stored detection state.

set -euo pipefail

REPO="${1:?usage: $0 <owner/repo> <pr-number>}"
PR_NUMBER="${2:?missing pr-number}"

MARKER_PREFIX='<!-- api-additions-signoff'

COMMENT_JSON=$(gh api --paginate \
  "repos/$REPO/issues/$PR_NUMBER/comments" \
  --jq "[.[] | select(.user.login == \"github-actions[bot]\" and (.body | startswith(\"$MARKER_PREFIX\")))] | .[0] // empty" | head -c 1048576)

if [ -z "$COMMENT_JSON" ]; then
  echo "comment_id="
  echo "stored_head="
  echo "stored_hash="
  echo "stored_count="
  echo "stored_tooling="
  echo "No marker comment found on PR #$PR_NUMBER." >&2
  exit 0
fi

COMMENT_ID=$(jq -r .id <<<"$COMMENT_JSON")
META=$(jq -r .body <<<"$COMMENT_JSON" | head -n 1)

echo "comment_id=$COMMENT_ID"
echo "stored_head=$(sed -n 's/.*head=\([0-9a-f]*\).*/\1/p' <<<"$META")"
echo "stored_hash=$(sed -n 's/.*hash=\([0-9a-f]*\).*/\1/p' <<<"$META")"
echo "stored_count=$(sed -n 's/.*count=\([0-9]*\).*/\1/p' <<<"$META")"
echo "stored_tooling=$(sed -n 's/.*tooling=\([01]\).*/\1/p' <<<"$META")"
echo "Marker comment $COMMENT_ID: $META" >&2
