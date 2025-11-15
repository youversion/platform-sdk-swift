#!/bin/bash
set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Error: Version parameter is required"
  exit 1
fi

echo "Updating version to $VERSION in all podspec files..."

# Update each podspec file
sed -i '' "s/spec.version[[:space:]]*=.*/spec.version = \"$VERSION\"/" YouVersionPlatform.podspec
sed -i '' "s/spec.version[[:space:]]*=.*/spec.version = \"$VERSION\"/" YouVersionPlatformCore.podspec
sed -i '' "s/spec.version[[:space:]]*=.*/spec.version = \"$VERSION\"/" YouVersionPlatformReader.podspec
sed -i '' "s/spec.version[[:space:]]*=.*/spec.version = \"$VERSION\"/" YouVersionPlatformUI.podspec

echo "Updating inter-pod dependency versions..."

# Update dependency versions within podspecs
sed -i '' "s/dependency 'YouVersionPlatformCore', '[^']*'/dependency 'YouVersionPlatformCore', '$VERSION'/" YouVersionPlatform.podspec
sed -i '' "s/dependency 'YouVersionPlatformCore', '[^']*'/dependency 'YouVersionPlatformCore', '$VERSION'/" YouVersionPlatformUI.podspec
sed -i '' "s/dependency 'YouVersionPlatformCore', '[^']*'/dependency 'YouVersionPlatformCore', '$VERSION'/" YouVersionPlatformReader.podspec
sed -i '' "s/dependency 'YouVersionPlatformUI', '[^']*'/dependency 'YouVersionPlatformUI', '$VERSION'/" YouVersionPlatformReader.podspec
sed -i '' "s/dependency 'YouVersionPlatformUI', '[^']*'/dependency 'YouVersionPlatformUI', '$VERSION'/" YouVersionPlatform.podspec
sed -i '' "s/dependency 'YouVersionPlatformReader', '[^']*'/dependency 'YouVersionPlatformReader', '$VERSION'/" YouVersionPlatform.podspec

echo "Validating podspecs..."

# Validate each podspec (allows warnings for now)
pod spec lint YouVersionPlatformCore.podspec --allow-warnings --quick
pod spec lint YouVersionPlatformUI.podspec --allow-warnings --quick
pod spec lint YouVersionPlatformReader.podspec --allow-warnings --quick
pod spec lint YouVersionPlatform.podspec --allow-warnings --quick

echo "Version update to $VERSION complete!"
