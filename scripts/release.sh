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
# Fresh-run pre-conditions (enforced below):
# - VERSION env var: the chosen target version.
# - HEAD = origin/main HEAD.
# - SDKVersion.swift reads "Dev".
# - Working tree clean.
# - Git identity configured.
# - SSH remote configured for push.
# - GH_TOKEN (or GITHUB_TOKEN) exported for `gh release create`.
#
# Resume mode (auto-detected): if tag $VERSION already exists on origin
# with a tree that has SDKVersion stamped to $VERSION,
# the script treats this as a re-dispatch after a prior partial run. It
# checks out the tag, regenerates the release notes, and proceeds to the
# idempotent post-tag steps (push, GitHub release, Dev-restore),
# each of which detects and skips already-completed work. See
# RELEASE-RUNBOOK.md for failure-mode-by-failure-mode recovery details.
#
# Post-conditions on success:
# - Tag $VERSION points at commit X (chore(release) commit stamping
#   SDKVersion and prepending the CHANGELOG entry).
# - main HEAD = Y (Dev-restore commit on top of X).
# - GitHub release created from the generated notes.
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

# In resume mode, $VERSION will equal $CURRENT_TAG (the tag already exists),
# which release-validate.mjs rejects with code 12 ("not strictly greater").
# Detect resume *before* failing on that, so re-dispatch with the same
# version recovers a partial run instead of exiting.
REMOTE_TAG_SHA=$(git ls-remote origin "refs/tags/$VERSION" 2>/dev/null | awk '{print $1}')
RESUME=0
if [ -n "$REMOTE_TAG_SHA" ]; then
  RESUME=1
fi

if [ "$VALIDATION_CODE" -eq 11 ]; then
  echo "❌ '$VERSION' is not valid semver" >&2
  exit 1
elif [ "$VALIDATION_CODE" -eq 12 ] && [ "$RESUME" = "0" ]; then
  echo "❌ '$VERSION' is not strictly greater than current tag '$CURRENT_TAG'" >&2
  exit 1
elif [ "$VALIDATION_CODE" -ne 0 ] && [ "$VALIDATION_CODE" -ne 12 ]; then
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
    if [ "$RESUME" = "1" ]; then
      echo
      echo "> 🔁 **Resume mode** — tag \`$VERSION\` already exists on origin. Will skip already-completed phases."
    fi
    if [ "$DRY_RUN" = "1" ]; then
      echo
      echo "> 🧪 **DRY_RUN=1** — workflow will stop before push/publish/restore."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

# Warn (don't block) if chosen version is more than one major above calculated.
# Skip the warning in resume mode — the decision was made on the original run.
if [ "$RESUME" = "0" ]; then
  node scripts/release-warn-version-jump.mjs "$VERSION" "$CALCULATED" >&2 || true
fi

# --- Resume-mode setup ------------------------------------------------------
#
# When tag $VERSION already exists on origin, verify the tag's tree matches
# what a normal release would have produced, then check the tag out so HEAD
# is the X commit regardless of where origin/main currently points.
#
# Why content-verify the tag: a rogue or mismatched tag (different content,
# moved by hand, leftover from a different process) must abort, not silently
# heal. Healing the wrong tag would push unrelated work to consumers.
#
# Why also overlay scripts/ from origin/main: the tag may predate this resume
# logic, so running the tagged tree's scripts would use stale post-tag steps
# (Dev-restore in particular) instead of the current ones.

if [ "$RESUME" = "1" ]; then
  echo
  echo "🔁 Resume mode: tag $VERSION already exists on origin at $REMOTE_TAG_SHA."

  # Make sure the tag is in the local refs (workflow checkout fetches tags,
  # but local dev runs may not).
  if ! git rev-parse "refs/tags/$VERSION^{}" >/dev/null 2>&1; then
    git fetch origin "refs/tags/$VERSION:refs/tags/$VERSION"
  fi

  TAG_SDK_LINE=$(git show "refs/tags/$VERSION:Sources/YouVersionPlatformCore/SDKVersion.swift" 2>/dev/null \
    | grep 'static let current' | head -1 || echo "")
  if ! echo "$TAG_SDK_LINE" | grep -qF "static let current = \"$VERSION\""; then
    echo "❌ Tag $VERSION exists but its tree's SDKVersion.swift does not read \"$VERSION\"." >&2
    echo "   Found: $TAG_SDK_LINE" >&2
    echo "   Refusing to resume against a tag whose content does not match. See RELEASE-RUNBOOK.md." >&2
    exit 1
  fi
  echo "  ✓ Tag $VERSION content matches (SDKVersion stamped to $VERSION)."

  # Detach onto the tag so all post-tag steps operate from X.
  git checkout --detach "refs/tags/$VERSION"

  # Replace scripts/ with origin/main's copy so we pick up post-tag fixes
  # (retry-with-backoff, idempotency checks, etc.) when re-running.
  git fetch origin main 2>/dev/null || true
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    git checkout origin/main -- scripts/
    echo "  ✓ Overlaid scripts/ from origin/main so resume uses the latest post-tag logic."
  fi

  # Regenerate notes using the same commit range the original run used.
  # Using --head $VERSION (the tag) is intentional: commits that landed on
  # main after X must not leak into this release's body.
  PREV_TAG=$(git describe --tags --abbrev=0 "refs/tags/$VERSION^" 2>/dev/null || echo "")
  if [ -z "$PREV_TAG" ]; then
    echo "❌ Could not derive previous tag (parent of $VERSION)." >&2
    exit 1
  fi
  echo "  Regenerating release notes for $VERSION (from $PREV_TAG)..."
  node scripts/generate-release-notes.mjs \
    --base "$PREV_TAG" \
    --head "$VERSION" \
    --version "$VERSION" \
    > notes.md
  echo "  Notes: $(wc -l < notes.md | tr -d ' ') lines."
fi

# --- Fresh-run pre-flight + commit-X build ---------------------------------

if [ "$RESUME" = "0" ]; then
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
    HEAD_SHA_CHECK=$(git rev-parse HEAD)
    MAIN_SHA_CHECK=$(git rev-parse origin/main 2>/dev/null || echo "")
    if [ -z "$MAIN_SHA_CHECK" ]; then
      echo "❌ origin/main ref not found locally — workflow checkout must use fetch-depth: 0" >&2
      exit 1
    fi
    if [ "$HEAD_SHA_CHECK" != "$MAIN_SHA_CHECK" ]; then
      echo "❌ HEAD ($HEAD_SHA_CHECK) is not at origin/main ($MAIN_SHA_CHECK)" >&2
      echo "   Live releases must be dispatched on the main branch. Re-run with --ref main." >&2
      exit 1
    fi
  fi

  # Tag-already-exists is only a fresh-run failure. Resume mode requires it.
  if git rev-parse "refs/tags/$VERSION" >/dev/null 2>&1; then
    echo "❌ Tag $VERSION already exists locally but not on origin — refusing to fresh-run." >&2
    echo "   If you intended to resume, push the tag first or delete it locally." >&2
    exit 1
  fi

  # --- Generate release notes -----------------------------------------------

  echo
  echo "Generating release notes..."
  node scripts/generate-release-notes.mjs \
    --base "$CURRENT_TAG" \
    --head HEAD \
    --version "$VERSION" \
    > notes.md
  echo "Notes: $(wc -l < notes.md | tr -d ' ') lines."

  # --- Update CHANGELOG.md --------------------------------------------------

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

  # --- Stamp version into source files --------------------------------------

  bash scripts/stamp-sdk-version.sh "$VERSION"

  # --- Build X commit -------------------------------------------------------

  git add \
    CHANGELOG.md \
    Sources/YouVersionPlatformCore/SDKVersion.swift

  # Subject + blank + notes body. [skip ci] prevents push-triggered workflows
  # from re-running on the release commit.
  {
    printf 'chore(release): %s [skip ci]\n\n' "$VERSION"
    cat notes.md
  } > .git/COMMIT_EDITMSG
  git commit -F .git/COMMIT_EDITMSG

  X_SHA=$(git rev-parse HEAD)
  echo "Commit X created at $X_SHA."

  # --- Tag X --------------------------------------------------------------

  git tag "$VERSION"
  echo "Tag $VERSION created at $X_SHA."
else
  X_SHA=$(git rev-parse HEAD)
  echo "  ✓ Using existing tag $VERSION at $X_SHA as commit X."
fi

# --- Dry-run exit (both modes) ---------------------------------------------

if [ "$DRY_RUN" = "1" ]; then
  echo
  if [ "$RESUME" = "1" ]; then
    echo "DRY_RUN=1 (resume mode) — stopping before push, GitHub release, and Dev restore."
    echo "Inspect locally:"
    echo "  cat notes.md"
    echo "  git log -1 $VERSION"
  else
    echo "DRY_RUN=1 — stopping before push, GitHub release, and Dev restore."
    echo "Inspect locally:"
    echo "  git log -1"
    echo "  git tag -l '$VERSION'"
    echo "  cat notes.md"
  fi
  exit 0
fi

# --- Push main + tag (idempotent) ------------------------------------------

echo
echo "Pushing main and tag $VERSION..."

# Refresh remote-tracking refs so the comparison below is accurate.
git fetch origin main 2>/dev/null || true
ORIGIN_MAIN_SHA=$(git rev-parse origin/main 2>/dev/null || echo "")

if [ "$RESUME" = "0" ]; then
  # Fresh run: X is local, push it.
  git push origin HEAD:main
elif [ "$ORIGIN_MAIN_SHA" = "$X_SHA" ]; then
  echo "  ✓ origin/main already at $X_SHA — skipping main push."
elif [ -n "$ORIGIN_MAIN_SHA" ] && git merge-base --is-ancestor "$X_SHA" "$ORIGIN_MAIN_SHA" 2>/dev/null; then
  # Resume after a successful X-push where Y or unrelated commits subsequently
  # landed on main. Don't try to re-push HEAD:main from a detached tag head;
  # the Dev-restore step handles the main-branch case.
  echo "  ✓ origin/main has advanced past X (likely Y already created) — skipping main push."
else
  echo "❌ Resume mode: tag $VERSION at $X_SHA is not reachable from origin/main ($ORIGIN_MAIN_SHA)." >&2
  echo "   Refusing to push from a detached state that doesn't descend from main. See RELEASE-RUNBOOK.md." >&2
  exit 1
fi

REMOTE_TAG_NOW=$(git ls-remote origin "refs/tags/$VERSION" 2>/dev/null | awk '{print $1}')
if [ -z "$REMOTE_TAG_NOW" ]; then
  git push origin "$VERSION"
elif [ "$REMOTE_TAG_NOW" = "$X_SHA" ]; then
  echo "  ✓ Tag $VERSION already at $X_SHA on origin — skipping tag push."
else
  echo "❌ Tag $VERSION on origin points at $REMOTE_TAG_NOW, but local X is $X_SHA." >&2
  echo "   Refusing to force-update tags. See RELEASE-RUNBOOK.md." >&2
  exit 1
fi

# --- Create GitHub release (idempotent) ------------------------------------

echo
if gh release view "$VERSION" >/dev/null 2>&1; then
  echo "GitHub release $VERSION already exists — leaving as-is."
else
  echo "Creating GitHub release..."
  gh release create "$VERSION" --notes-file notes.md --title "$VERSION"
fi

# --- Restore Dev on main (Y commit) ----------------------------------------
#
# In resume mode HEAD is detached at the tag, but Dev-restore must commit
# on top of origin/main. Switch to main first.

if [ "$RESUME" = "1" ]; then
  echo
  echo "Resume: checking out main before Dev-restore..."
  git fetch origin main
  # -B re-creates main from origin/main (in CI this is a fresh branch; in
  # local re-runs it resets any local main to origin/main, which is what
  # we want — no stale local diverge).
  git checkout -B main origin/main
fi

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
