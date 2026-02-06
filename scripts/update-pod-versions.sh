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

echo "Validating podspecs..."

# Validate each podspec (allows warnings for now)
pod spec lint YouVersionPlatformCore.podspec --allow-warnings --quick
pod spec lint YouVersionPlatformUI.podspec --allow-warnings --quick
pod spec lint YouVersionPlatformReader.podspec --allow-warnings --quick
pod spec lint YouVersionPlatform.podspec --allow-warnings --quick

echo "Version update to $VERSION complete!"
