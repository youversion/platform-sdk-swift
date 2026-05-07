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
#   main:  ... ─ X (SDKVersion=$VERSION, podspec=$VERSION)   ← TAG $VERSION
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
# - HEAD is X (semantic-release's release commit, just pushed to main).
# - SDKVersion.swift at HEAD reads "$VERSION" (set by prepareCmd's
#   stamp-sdk-version.sh invocation).
# - Tag $VERSION exists locally and on origin, pointing at HEAD.
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

# 2. Tag $VERSION must exist and point at HEAD. semantic-release creates and
#    pushes the tag between prepare and publish; if it didn't (or pointed
#    elsewhere), our topology assumption is broken.
#
#    Use refs/tags/$VERSION^{} to dereference to the target commit. This is
#    a no-op for lightweight tags (which is what semantic-release creates
#    today) but correctly resolves annotated tags to their commit SHA, so
#    the comparison stays valid if any plugin or upstream change starts
#    producing annotated tags.
TAG_SHA=$(git rev-parse "refs/tags/$VERSION^{}" 2>/dev/null || echo "")
HEAD_SHA=$(git rev-parse HEAD)
if [ -z "$TAG_SHA" ]; then
  echo "❌ Tag $VERSION does not exist locally." >&2
  echo "   semantic-release should have created it before invoking this script." >&2
  exit 1
fi
if [ "$TAG_SHA" != "$HEAD_SHA" ]; then
  echo "❌ Tag $VERSION points at $TAG_SHA but HEAD is $HEAD_SHA." >&2
  echo "   Aborting before pushing Dev-restore — this would leave the tag and main out of sync." >&2
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
