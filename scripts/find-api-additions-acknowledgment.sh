#!/bin/bash
#
# Scan a PR's comments for a qualifying acknowledgment of public API additions.
# Used by .github/workflows/api-additions-signoff-gate.yml on both
# workflow_run and issue_comment events so the matching rules live in exactly
# one place.
#
# Usage:
#   find-api-additions-acknowledgment.sh <owner/repo> <pr-number> <pr-author> <symbol-list-hash>
#
# Prints GITHUB_OUTPUT-style lines to stdout (human notes go to stderr):
#   approver=<login>       (empty when no qualifying acknowledgment exists)
#   approver_url=<url>
#
# A qualifying comment must:
#   1. contain the verbatim acknowledgment phrase (quote markers stripped and
#      whitespace collapsed, same normalization as major-release-signoff.yml),
#   2. contain "API-hash: <hash>" for the *current* symbol list, so an
#      acknowledgment of an older set of additions never carries over,
#   3. be authored by a non-bot collaborator with write+ permission who is not
#      the PR author (second pair of eyes, matching the breaking-change gate).
#      Permission lookups fail closed: a lookup error counts as no permission.

set -euo pipefail

REPO="${1:?usage: $0 <owner/repo> <pr-number> <pr-author> <symbol-list-hash>}"
PR_NUMBER="${2:?missing pr-number}"
PR_AUTHOR="${3:?missing pr-author}"
HASH="${4:?missing symbol-list-hash}"

# Keep in sync with the copy-paste block the workflow puts in its PR comment.
TEMPLATE_PHRASE='I confirm these public API additions are intentional and we are committing to support them.'

# Normalize: drop `>` quote markers and collapse all whitespace (incl.
# newlines) to a single space, so "Quote reply" output, hard-wrapped lines,
# and CRLF-vs-LF all match.
normalize() {
  printf '%s' "$1" | tr -d '>' | tr -s '[:space:]' ' '
}
NORM_TEMPLATE=$(normalize "$TEMPLATE_PHRASE")

COMMENTS=$(gh api --paginate \
  "repos/$REPO/issues/$PR_NUMBER/comments" \
  --jq '[.[] | {login: .user.login, type: .user.type, body: .body, html_url: .html_url}]')

# Cache permission lookups so a chatty approver doesn't cost one API call per
# comment.
declare -A PERM_CACHE
MATCH_LOGIN=""
MATCH_URL=""
while IFS= read -r row; do
  LOGIN=$(jq -r .login <<<"$row")
  BODY=$(jq -r .body <<<"$row")
  URL=$(jq -r .html_url <<<"$row")
  USER_TYPE=$(jq -r .type <<<"$row")
  # Bots can't acknowledge, and neither can the PR author — the gate exists
  # to get a second pair of eyes on the new API surface.
  if [ "$USER_TYPE" = "Bot" ]; then
    continue
  fi
  if [ "$LOGIN" = "$PR_AUTHOR" ]; then
    continue
  fi
  # Content match first: cheap, and most comments won't qualify.
  NORM_BODY=$(normalize "$BODY")
  if [[ "$NORM_BODY" != *"$NORM_TEMPLATE"* ]]; then
    continue
  fi
  if [[ "$NORM_BODY" != *"API-hash: $HASH"* ]]; then
    continue
  fi
  # Then verify the commenter has write+ permission on this repo.
  PERM="${PERM_CACHE[$LOGIN]:-}"
  if [ -z "$PERM" ]; then
    PERM=$(gh api "repos/$REPO/collaborators/$LOGIN/permission" \
      --jq '.permission' 2>/dev/null || echo "none")
    PERM_CACHE[$LOGIN]="$PERM"
  fi
  case "$PERM" in
    admin|maintain|write)
      MATCH_LOGIN="$LOGIN"
      MATCH_URL="$URL"
      break
      ;;
  esac
done < <(jq -c '.[]' <<<"$COMMENTS")

echo "approver=$MATCH_LOGIN"
echo "approver_url=$MATCH_URL"
if [ -n "$MATCH_LOGIN" ]; then
  echo "Acknowledgment found: $MATCH_LOGIN ($MATCH_URL)" >&2
else
  echo "No qualifying acknowledgment found yet." >&2
fi
