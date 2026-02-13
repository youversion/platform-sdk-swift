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
#
# To enable CocoaPods publishing, uncomment the `pod trunk push` lines below.
# A delay between each push allows the CocoaPods CDN to index the previous pod
# before a dependent pod is pushed.

echo ""
echo "Step 1/4: Publishing YouVersionPlatformCore..."
pod trunk push YouVersionPlatformCore.podspec --allow-warnings --synchronous
#echo "Waiting for CDN propagation..."
#sleep 60

echo ""
echo "Step 2/4: Publishing YouVersionPlatformUI..."
pod trunk push YouVersionPlatformUI.podspec --allow-warnings --synchronous
#echo "Waiting for CDN propagation..."
#sleep 60

echo ""
echo "Step 3/4: Publishing YouVersionPlatformReader..."
pod trunk push YouVersionPlatformReader.podspec --allow-warnings --synchronous
#echo "Waiting for CDN propagation..."
#sleep 60

echo ""
echo "Step 4/4: Publishing YouVersionPlatform..."
pod trunk push YouVersionPlatform.podspec --allow-warnings --synchronous

echo ""
echo "✅ Pod version $VERSION was pushed to trunk."
