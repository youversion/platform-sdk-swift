#!/bin/bash
set -e

# Change to repository root directory (parent of scripts/)
cd "$(dirname "$0")/.."

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Error: Version parameter is required"
  exit 1
fi

echo "Updating version to $VERSION in all podspec files..."

# Update s.version in each podspec file.
# Inter-pod dependencies use s.version.to_s, so they automatically stay in sync.
sed -i '' "s/s\.version[[:space:]]*=.*/s.version      = '$VERSION'/" YouVersionPlatform.podspec
sed -i '' "s/s\.version[[:space:]]*=.*/s.version      = '$VERSION'/" YouVersionPlatformCore.podspec
sed -i '' "s/s\.version[[:space:]]*=.*/s.version      = '$VERSION'/" YouVersionPlatformReader.podspec
sed -i '' "s/s\.version[[:space:]]*=.*/s.version      = '$VERSION'/" YouVersionPlatformUI.podspec

echo "Verifying version was updated..."
for PODSPEC in YouVersionPlatform.podspec YouVersionPlatformCore.podspec YouVersionPlatformReader.podspec YouVersionPlatformUI.podspec; do
  if ! grep -q "s.version      = '$VERSION'" "$PODSPEC"; then
    echo "Error: Failed to update version in $PODSPEC"
    exit 1
  fi
  echo "  ✓ $PODSPEC"
done

echo "Validating podspecs (full xcodebuild — slow but mirrors trunk)..."

# Use `pod lib lint` rather than `pod spec lint`. `spec lint` clones the
# source URL at the spec's :tag — which doesn't exist yet during the
# prepare phase, before the release tag is pushed. `lib lint` uses local
# working-directory sources instead, so it works pre-tag.
#
# Crucially, run WITHOUT --quick so xcodebuild actually compiles. The
# --quick flag was the gate that let the May 1 5.0.0 release through:
# `pod trunk push` later does a full build and caught a missing
# -package-name for a `package`-access symbol, by which point the
# release was committed. Building here surfaces that class of error
# while we still can fail safely.
#
# '--include-podspecs=*.podspec' lets dependent pods resolve their
# inter-pod deps from local podspec files instead of CocoaPods trunk —
# necessary because the new version isn't published yet at this point.
pod lib lint YouVersionPlatformCore.podspec --allow-warnings
pod lib lint YouVersionPlatformUI.podspec --allow-warnings '--include-podspecs=*.podspec'
pod lib lint YouVersionPlatformReader.podspec --allow-warnings '--include-podspecs=*.podspec'
pod lib lint YouVersionPlatform.podspec --allow-warnings '--include-podspecs=*.podspec'

echo "Version update to $VERSION complete!"
