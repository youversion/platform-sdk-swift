#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="${BASE_SHA:?BASE_SHA is required}"
HEAD_SHA="${HEAD_SHA:?HEAD_SHA is required}"
PR_AUTHOR="${PR_AUTHOR:-}"
HEAD_REF="${HEAD_REF:-}"
ACTOR="${ACTOR:-}"

# GitHub App identities surface as "<slug>[bot]" in pull_request.user.login and
# as "app/<slug>" in some CLI/API contexts; accept both.
LOCALIZATION_SYNC_BOT_APP="app/platform-localization-pr-bot"
LOCALIZATION_SYNC_BOT_USER="platform-localization-pr-bot[bot]"
LOCALE_PATH="Sources/YouVersionPlatformUI/Resources/Localizable.xcstrings"
FAILURE_MSG="Localizable.xcstrings is owned by platform-localization. Add strings upstream; do not edit ${LOCALE_PATH} in feature PRs. See docs/localization-guardrails.md"

is_sync_bot_author() {
  [[ "$PR_AUTHOR" == "$LOCALIZATION_SYNC_BOT_APP" \
    || "$PR_AUTHOR" == "$LOCALIZATION_SYNC_BOT_USER" ]]
}

is_sync_branch() {
  [[ "$HEAD_REF" == "chore/localization-sync-swift" \
    || "$HEAD_REF" =~ ^chore/localization-sync-swift- ]]
}

is_allowed_sync_pr() {
  is_sync_bot_author && is_sync_branch
}

if is_allowed_sync_pr; then
  echo "Locale ownership check skipped: allowed localization sync PR (actor=${ACTOR:-<unset>}, author=${PR_AUTHOR:-<unset>}, branch=${HEAD_REF:-<unset>})"
  exit 0
fi

# Three-dot diff (merge-base) so catalog changes that landed on the base branch
# after this PR branched are not misattributed to the PR.
changed_files="$(git diff --name-only "${BASE_SHA}...${HEAD_SHA}" -- "$LOCALE_PATH")"

if [[ -z "$changed_files" ]]; then
  echo "Locale ownership check passed: no catalog changes"
  exit 0
fi

echo "::error title=Locale catalog is upstream-owned::${FAILURE_MSG}"
echo ""
echo "Changed catalog files:"
echo "$changed_files"
echo ""
echo "$FAILURE_MSG"
exit 1
