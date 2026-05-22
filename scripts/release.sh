#!/bin/bash
# Manual version-input release orchestrator.
#
# Called by .github/workflows/release.yml after `workflow_dispatch` with
# `inputs.version`. Bypasses semantic-release entirely. The analyzer and
# release-notes-generator modules are still used as libraries via
# scripts/preview-release.mjs and scripts/generate-release-notes.mjs,
# but orchestration is local — no env-ci, no verifyAuth, no lifecycle.
#
# Why this exists:
# - semantic-release has no hook to override the calculated version. The
#   only way to ship a version that differs from what the analyzer
#   computes is to commit-message-engineer history, which is brittle.
# - This script makes the chosen version an explicit input. The
#   analyzer's value is logged side-by-side for audit, but the human's
#   input wins.
#
# Pre-conditions when this runs (most enforced by the workflow):
# - VERSION env var: the chosen target version.
# - HEAD = origin/main HEAD.
# - SDKVersion.swift reads "Dev".
# - Working tree clean.
# - Git identity configured.
# - SSH remote configured for push.
# - GH_TOKEN (or GITHUB_TOKEN) exported for `gh release create`.
# - COCOAPODS_TRUNK_TOKEN exported for pod publish.
#
# Post-conditions on success:
# - Tag $VERSION points at commit X (chore(release) commit stamping
#   SDKVersion, all four podspecs, and prepending the CHANGELOG entry).
# - main HEAD = Y (Dev-restore commit on top of X).
# - GitHub release created from the generated notes.
# - All four pods (Core, UI, Reader, Platform) published at $VERSION.
#
# Local usage (validates and stops before push):
#   VERSION=5.2.3 DRY_RUN=1 bash scripts/release.sh
#
# CI usage:
#   VERSION=5.2.3 bash scripts/release.sh

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-}"
DRY_RUN="${DRY_RUN:-0}"

if [ -z "$VERSION" ]; then
  echo "❌ VERSION env var is required" >&2
  exit 1
fi

# --- Validate VERSION --------------------------------------------------------

CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
echo "Current tag:    $CURRENT_TAG"
echo "Chosen version: $VERSION"

VALIDATION_CODE=0
node scripts/release-validate.mjs "$VERSION" "$CURRENT_TAG" || VALIDATION_CODE=$?

if [ "$VALIDATION_CODE" -eq 11 ]; then
  echo "❌ '$VERSION' is not valid semver" >&2
  exit 1
elif [ "$VALIDATION_CODE" -eq 12 ]; then
  echo "❌ '$VERSION' is not strictly greater than current tag '$CURRENT_TAG'" >&2
  exit 1
elif [ "$VALIDATION_CODE" -ne 0 ]; then
  echo "❌ Version validation failed (exit $VALIDATION_CODE)" >&2
  exit 1
fi

# --- Compute calculated version (informational only) -------------------------

PREVIEW_JSON=$(node scripts/preview-release.mjs --base "$CURRENT_TAG" --head HEAD 2>/dev/null || echo '{}')
CALCULATED=$(echo "$PREVIEW_JSON" | node -e "let s=''; process.stdin.on('data', d=>s+=d).on('end', () => { const j=JSON.parse(s||'{}'); console.log(j.next || j.current || 'unknown'); });")
CALC_TYPE=$(echo "$PREVIEW_JSON" | node -e "let s=''; process.stdin.on('data', d=>s+=d).on('end', () => { const j=JSON.parse(s||'{}'); console.log(j.release_type || 'none'); });")
echo "Calculated:     $CALCULATED ($CALC_TYPE)"

# Write a side-by-side audit block to the GitHub Actions step summary
# when running in CI. Surfaces "calculator said X, human chose Y" in the
# job's web UI without needing to dig into the log.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Release \`$VERSION\`"
    echo
    echo "| Source            | Version            |"
    echo "| ----------------- | ------------------ |"
    echo "| Current tag       | \`$CURRENT_TAG\`   |"
    echo "| Analyzer-computed | \`$CALCULATED\` ($CALC_TYPE) |"
    echo "| Chosen (input)    | **\`$VERSION\`**   |"
    if [ "$DRY_RUN" = "1" ]; then
      echo
      echo "> 🧪 **DRY_RUN=1** — workflow will build commit X + tag locally, then stop. No push, no GitHub release, no pod publish."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

# Warn (don't block) if chosen version is more than one major above calculated.
node scripts/release-warn-version-jump.mjs "$VERSION" "$CALCULATED" >&2 || true

# --- Pre-flight -------------------------------------------------------------

if ! grep -q 'static let current = "Dev"' Sources/YouVersionPlatformCore/SDKVersion.swift; then
  echo "❌ SDKVersion.swift does not currently read \"Dev\" — main is in an unexpected state" >&2
  echo "   Current: $(grep 'static let current' Sources/YouVersionPlatformCore/SDKVersion.swift | head -1)" >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "❌ Working tree is dirty — aborting" >&2
  git status --short >&2
  exit 1
fi

# Guard against a non-main dispatch landing feature-branch commits on
# main. `gh workflow run release.yml --ref feature-branch` would pass
# every other pre-flight, and `git push origin HEAD:main` would then
# bypass branch protection via the deploy key. Dry-runs are explicitly
# supported on any branch (no push fires), so we skip this guard for them.
if [ "$DRY_RUN" != "1" ]; then
  HEAD_SHA=$(git rev-parse HEAD)
  MAIN_SHA=$(git rev-parse origin/main 2>/dev/null || echo "")
  if [ -z "$MAIN_SHA" ]; then
    echo "❌ origin/main ref not found locally — workflow checkout must use fetch-depth: 0" >&2
    exit 1
  fi
  if [ "$HEAD_SHA" != "$MAIN_SHA" ]; then
    echo "❌ HEAD ($HEAD_SHA) is not at origin/main ($MAIN_SHA)" >&2
    echo "   Live releases must be dispatched on the main branch. Re-run with --ref main." >&2
    exit 1
  fi
fi

if git rev-parse "refs/tags/$VERSION" >/dev/null 2>&1; then
  # Workflow checks out with fetch-depth: 0, so this also catches tags
  # already on origin — the local clone has every remote tag.
  echo "❌ Tag $VERSION already exists (in local refs, which include everything fetched from origin)" >&2
  exit 1
fi

# --- Generate release notes -------------------------------------------------

echo
echo "Generating release notes..."
node scripts/generate-release-notes.mjs \
  --base "$CURRENT_TAG" \
  --head HEAD \
  --version "$VERSION" \
  > notes.md
echo "Notes: $(wc -l < notes.md | tr -d ' ') lines."

# --- Update CHANGELOG.md ----------------------------------------------------

if [ -f CHANGELOG.md ]; then
  # Preserve title + intro; prepend the new entry above the first existing
  # version heading. If no existing version heading, append.
  node - <<'NODE'
const fs = require('fs');
const notes = fs.readFileSync('notes.md', 'utf8').trimEnd() + '\n\n';
const existing = fs.readFileSync('CHANGELOG.md', 'utf8');
const m = existing.match(/^## \[/m);
let out;
if (m) {
  out = existing.slice(0, m.index) + notes + existing.slice(m.index);
} else {
  out = existing.trimEnd() + '\n\n' + notes;
}
fs.writeFileSync('CHANGELOG.md', out);
NODE
else
  printf '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n' > CHANGELOG.md
  cat notes.md >> CHANGELOG.md
fi
echo "CHANGELOG.md updated."

# --- Stamp version into source files ----------------------------------------

bash scripts/update-pod-versions.sh "$VERSION"
bash scripts/stamp-sdk-version.sh "$VERSION"

# --- Build X commit ---------------------------------------------------------

git add \
  CHANGELOG.md \
  Sources/YouVersionPlatformCore/SDKVersion.swift \
  YouVersionPlatform.podspec \
  YouVersionPlatformCore.podspec \
  YouVersionPlatformReader.podspec \
  YouVersionPlatformUI.podspec

# Subject + blank + notes body. [skip ci] prevents push-triggered workflows
# from re-running on the release commit.
{
  printf 'chore(release): %s [skip ci]\n\n' "$VERSION"
  cat notes.md
} > .git/COMMIT_EDITMSG
git commit -F .git/COMMIT_EDITMSG

X_SHA=$(git rev-parse HEAD)
echo "Commit X created at $X_SHA."

# --- Tag X ------------------------------------------------------------------

git tag "$VERSION"
echo "Tag $VERSION created at $X_SHA."

if [ "$DRY_RUN" = "1" ]; then
  echo
  echo "DRY_RUN=1 — stopping before push, GitHub release, pod publish, and Dev restore."
  echo "Inspect locally:"
  echo "  git log -1"
  echo "  git tag -l '$VERSION'"
  echo "  cat notes.md"
  exit 0
fi

# --- Push main + tag --------------------------------------------------------

echo
echo "Pushing main and tag $VERSION..."
git push origin HEAD:main
git push origin "$VERSION"

# --- Create GitHub release --------------------------------------------------

echo
echo "Creating GitHub release..."
gh release create "$VERSION" --notes-file notes.md --title "$VERSION"

# --- Publish pods -----------------------------------------------------------

echo
echo "Publishing pods..."
bash scripts/publish-pods.sh "$VERSION"

# --- Restore Dev on main (Y commit) -----------------------------------------

echo
echo "Restoring SDKVersion to Dev on main..."
bash scripts/restore-dev-sdk-on-main.sh "$VERSION"

Y_SHA=$(git rev-parse HEAD)

# Clean up the generated notes file so a successful run leaves the repo
# tidy. The .gitignore entry covers the unlikely case where this rm
# doesn't fire (script killed, etc.), but removing it explicitly on the
# success path is the principled cleanup.
rm -f notes.md

echo
echo "✅ Release $VERSION complete."
echo "   Tag $VERSION -> $X_SHA (commit X)"
echo "   main HEAD     -> $Y_SHA (commit Y, SDKVersion=\"Dev\")"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo
    echo "### ✅ Released"
    echo
    echo "- Tag \`$VERSION\` → \`$X_SHA\` (commit X)"
    echo "- main HEAD → \`$Y_SHA\` (commit Y)"
    echo "- GitHub release: [\`$VERSION\`](https://github.com/${GITHUB_REPOSITORY:-youversion/platform-sdk-swift}/releases/tag/$VERSION)"
  } >> "$GITHUB_STEP_SUMMARY"
fi
