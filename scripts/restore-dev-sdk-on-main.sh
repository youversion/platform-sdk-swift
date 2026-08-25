#!/bin/bash
# Restore SDKVersion.swift to "Dev" on main as a follow-up commit Y after
# semantic-release's release commit X has been pushed and tagged. The
# release tag is NOT moved — it stays at X (which is on main), so
# semantic-release's `git tag --merged main` filter on the next run can
# discover this release as the previous-release base.
#
# Topology after this script runs (X is the @semantic-release/git release
# commit; Y is the commit this script creates):
#
#   main:  ... ─ X (SDKVersion=$VERSION)   ← TAG $VERSION
#                     ↓
#                     Y (SDKVersion="Dev")                   ← main HEAD
#
# Why this exists:
# - We want SDKVersion to read "Dev" on main between releases so PR CI and
#   in-repo dev builds don't report a stale released version to telemetry.
# - We want the release tag to point at a commit reachable from main so
#   semantic-release.getLastRelease() can find it via `git tag --merged
#   main` on the next release run. (The previous design moved the tag to
#   an off-main "Y" commit, which made every successful release invisible
#   to the next run and produced "tag already exists" collisions.)
#
# Both goals are satisfied by stamping SDKVersion=$VERSION in the prepare
# phase (so X carries it for the tag), then adding a Dev-restore commit
# Y on top of X here.
#
# Pre-conditions when this script runs:
# - HEAD is X, or (in release.sh resume mode where main diverged after X was
#   pushed) a descendant of X — i.e. tag $VERSION must be reachable from HEAD.
# - SDKVersion.swift at HEAD reads "$VERSION" (set by prepareCmd's
#   stamp-sdk-version.sh invocation; descendant commits should not be touching
#   SDKVersion.swift, so it still reads the version stamped at X).
# - Tag $VERSION exists locally and on origin, reachable from HEAD.
#
# Post-conditions on success:
# - main HEAD = Y, with SDKVersion.swift = "Dev".
# - Tag $VERSION = X (unchanged, still reachable from main via Y → X).
# - Working tree clean.
set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Error: Version parameter is required"
  exit 1
fi

cd "$(dirname "$0")/.."

# --- Already-restored fast path ---------------------------------------------
#
# When release.sh re-runs against an in-flight $VERSION (resume mode), this
# script may be called after a previous run already created the Y commit and
# pushed it. Detect that exact state and exit 0 — otherwise the strict
# pre-flights below (which expect HEAD=X with SDKVersion=$VERSION) would
# refuse to proceed and block recovery.
#
# Required state to recognize "Y already present":
#   - HEAD's SDKVersion.swift reads "Dev"
#   - Tag $VERSION is reachable from HEAD (ancestor-or-equal)
#   - Tag $VERSION's own tree has SDKVersion reading "$VERSION"
#
# Using an ancestor check (not strict HEAD~1 equality) covers both the normal
# topology (Y directly on X) and the diverged-main topology (Y on C on X,
# Failure Mode #3), where HEAD~1 is C — not X — and the strict parent check
# would incorrectly miss the already-restored state.
if grep -qF 'static let current = "Dev"' Sources/YouVersionPlatformCore/SDKVersion.swift; then
  TAG_SHA_FOR_IDEMP=$(git rev-parse "refs/tags/$VERSION^{}" 2>/dev/null || echo "")
  HEAD_SHA_FOR_IDEMP=$(git rev-parse HEAD 2>/dev/null || echo "")
  if [ -n "$TAG_SHA_FOR_IDEMP" ] && [ -n "$HEAD_SHA_FOR_IDEMP" ] && \
     git merge-base --is-ancestor "$TAG_SHA_FOR_IDEMP" "$HEAD_SHA_FOR_IDEMP" 2>/dev/null; then
    TAG_SDK_LINE_IDEMP=$(git show "refs/tags/$VERSION:Sources/YouVersionPlatformCore/SDKVersion.swift" 2>/dev/null \
      | grep 'static let current' | head -1 || echo "")
    if echo "$TAG_SDK_LINE_IDEMP" | grep -qF "static let current = \"$VERSION\""; then
      echo "✓ Dev-restore commit Y for $VERSION already present at HEAD — nothing to do."
      exit 0
    fi
  fi
fi

# --- Pre-flight assertions ---------------------------------------------------

# 1. SDKVersion at HEAD must read $VERSION. If not, prepareCmd is
#    misconfigured (likely missing stamp-sdk-version.sh) and we'd
#    incorrectly "restore" something that was never stamped.
EXPECTED_LINE="static let current = \"$VERSION\""
if ! grep -qF "$EXPECTED_LINE" Sources/YouVersionPlatformCore/SDKVersion.swift; then
  echo "❌ SDKVersion.swift at HEAD does not read \"$VERSION\"." >&2
  echo "   Found: $(grep 'static let current' Sources/YouVersionPlatformCore/SDKVersion.swift | head -1)" >&2
  echo "   Expected prepareCmd to have run stamp-sdk-version.sh $VERSION before @semantic-release/git committed." >&2
  exit 1
fi

# 2. Tag $VERSION must exist and be reachable from HEAD. The release script
#    creates and pushes the tag at X between prepare and publish; if it
#    didn't (or pointed somewhere disjoint), our topology assumption is
#    broken.
#
#    Use refs/tags/$VERSION^{} to dereference to the target commit. This is
#    a no-op for lightweight tags (which is what we create today) but
#    correctly resolves annotated tags to their commit SHA, so the
#    reachability check stays valid if any plugin or upstream change starts
#    producing annotated tags.
#
#    Reachability (ancestor-or-equal), not strict equality: in release.sh
#    resume mode after a diverged-main failure (RELEASE-RUNBOOK.md Failure
#    Mode #3), HEAD is origin/main = C — an unrelated commit on top of X,
#    not X itself. The resulting topology X → C → Y is still valid (tag
#    stays at X; X is reachable from main via Y → C → X).
TAG_SHA=$(git rev-parse "refs/tags/$VERSION^{}" 2>/dev/null || echo "")
HEAD_SHA=$(git rev-parse HEAD)
if [ -z "$TAG_SHA" ]; then
  echo "❌ Tag $VERSION does not exist locally." >&2
  echo "   semantic-release should have created it before invoking this script." >&2
  exit 1
fi
if ! git merge-base --is-ancestor "$TAG_SHA" "$HEAD_SHA"; then
  echo "❌ Tag $VERSION at $TAG_SHA is not reachable from HEAD ($HEAD_SHA)." >&2
  echo "   Aborting before pushing Dev-restore — the tag and main would end up disjoint." >&2
  exit 1
fi

# 3. Working tree must be clean (semantic-release just committed everything).
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "❌ Working tree is dirty before Dev-restore." >&2
  echo "   Aborting — manual intervention required." >&2
  git status --short >&2
  exit 1
fi

# --- Restore SDKVersion to "Dev" ---------------------------------------------

echo "Restoring SDKVersion to 'Dev' on main..."
bash scripts/stamp-sdk-version.sh Dev

git add Sources/YouVersionPlatformCore/SDKVersion.swift

# `chore(release):` matches the type-enum allowed by commitlint and avoids
# triggering another semantic-release run via the [skip ci] suffix.
git commit -m "chore(release): restore SDKVersion to Dev after $VERSION [skip ci]"

# Plain (non-force) push. If anything else landed on main between
# @semantic-release/git's push of X and now (rare — same workflow run, no
# concurrent CI), the push will fail and exit non-zero. We DO NOT want to
# overwrite a third-party commit; better to fail loudly and let a human
# rebase Y onto new main and re-push.
echo "Pushing Dev-restore commit Y to main (fast-forward)..."
git push origin HEAD:main

echo "✅ Tag $VERSION → X (on main); main HEAD = Y with SDKVersion=\"Dev\"."
