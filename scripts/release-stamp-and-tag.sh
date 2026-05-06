#!/bin/bash
# Stamp the SDK version into source AND move the release tag to point at the
# stamped commit (a child of main HEAD, NOT pushed to main).
#
# Topology after this script runs:
#
#   main:  ... ─ X (podspec=$VERSION, CHANGELOG, SDKVersion="Dev")    ← main HEAD
#                     \
#                      Y (… +SDKVersion="$VERSION")                   ← tag $VERSION
#
# Why: keep `main` reading "Dev" continuously (so in-repo dev builds and PR
# CI report SwiftSDK=Dev), while production builds fetched via SPM or
# CocoaPods at a release tag report the real version.
#
# This script runs during semantic-release's publish phase, *before*
# publish-pods.sh, so that `pod trunk push`'s spec lint clones the
# stamped tag commit.
set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Error: Version parameter is required"
  exit 1
fi

cd "$(dirname "$0")/.."

echo "Stamping SDK version into source..."
bash scripts/stamp-sdk-version.sh "$VERSION"

echo "Creating tag-only commit Y as child of main HEAD..."
git add Sources/YouVersionPlatformCore/SDKVersion.swift
# Use chore(release): to match the on-main release commit format from
# @semantic-release/git and to satisfy the commitlint config (which only
# permits the conventional-commits type-enum: feat, fix, docs, style,
# refactor, perf, test, build, ci, chore, revert). The husky commit-msg
# hook runs in CI (npm ci → "prepare": "husky" installs it), so a
# non-conforming type would reject the commit and abort the release.
git commit -m "chore(release): stamp SDKVersion ${VERSION} (tag-only, not on main) [skip ci]"

echo "Moving tag $VERSION to the stamped commit..."
git tag -f "$VERSION"

# Force-push the tag ref. This carries commit Y to origin (because the tag
# points to it) but does NOT advance the main branch ref. If the tag already
# exists on origin (semantic-release may have pushed it pointing at X), the
# force flag overwrites it.
#
# This tag-only push does NOT trigger release.yml: that workflow's trigger
# is `on: push: branches: [main]`, which matches refs/heads/main only —
# refs/tags/* pushes are ignored. The on-main release commit X (created
# earlier by @semantic-release/git) also carries `[skip ci]` per
# .releaserc.json, so even an accidental main-ref push wouldn't loop.
echo "Pushing tag $VERSION (force, tag-only — not pushing main)..."
git push --force origin "refs/tags/$VERSION"

# Reset working tree back to origin/main so any subsequent release steps see
# a clean main and cannot accidentally push commit Y to main.
echo "Resetting working tree to origin/main..."
git reset --hard origin/main

echo "✅ Release tag $VERSION now points at SDKVersion-stamped commit (off-main)."
