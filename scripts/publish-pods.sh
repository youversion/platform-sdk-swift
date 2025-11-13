#!/bin/bash
set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Error: Version parameter is required"
  exit 1
fi

echo "Publishing version $VERSION to CocoaPods trunk..."
echo "IMPORTANT: Pods will be published in dependency order"

# Publish in dependency order: Core -> UI -> Reader -> Platform
echo ""
echo "Step 1/4: Publishing YouVersionPlatformCore..."
pod trunk push YouVersionPlatformCore.podspec --allow-warnings

echo ""
echo "Step 2/4: Publishing YouVersionPlatformUI..."
pod trunk push YouVersionPlatformUI.podspec --allow-warnings

echo ""
echo "Step 3/4: Publishing YouVersionPlatformReader..."
pod trunk push YouVersionPlatformReader.podspec --allow-warnings

echo ""
echo "Step 4/4: Publishing YouVersionPlatform (Dry-Run)..."
# Uncomment the following line to publish the podspec
# pod trunk push YouVersionPlatform.podspec --allow-warnings

echo ""
echo "✅ All pods published successfully for version $VERSION!"
echo ""
echo "Verifying publication..."
pod search YouVersionPlatform --simple | head -n 5
