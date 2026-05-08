#!/bin/bash
set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Error: Version parameter is required"
  exit 1
fi

# `pod trunk push` is non-idempotent (re-running for an already-published
# version exits non-zero) and can also exit non-zero AFTER trunk has accepted
# the spec (e.g. "Calling the GitHub commit API timed out"). Either case can
# leave a release half-published. Before each push, ask trunk whether <pod>
# already lists <version> and skip if so — making the script resumable after
# a partial failure.
pod_already_published() {
  local pod="$1"
  local version="$2"
  local escaped="${version//./\\.}"
  # "**Regex anchored to a specific `pod trunk info` output format**"
  pod trunk info "$pod" 2>/dev/null \
    | grep -Eq "^[[:space:]]+- ${escaped} \("
}

publish_pod() {
  local pod_name="$1"
  local podspec="$2"
  if pod_already_published "$pod_name" "$VERSION"; then
    echo "  ✓ $pod_name $VERSION already on trunk — skipping"
    return 0
  fi
  pod trunk push "$podspec" --allow-warnings --synchronous
}

echo "Publishing version $VERSION to CocoaPods trunk..."
echo "IMPORTANT: Pods will be published in dependency order; already-published versions are skipped"

echo ""
echo "Step 1/4: YouVersionPlatformCore"
publish_pod YouVersionPlatformCore YouVersionPlatformCore.podspec

echo ""
echo "Step 2/4: YouVersionPlatformUI"
publish_pod YouVersionPlatformUI YouVersionPlatformUI.podspec

echo ""
echo "Step 3/4: YouVersionPlatformReader"
publish_pod YouVersionPlatformReader YouVersionPlatformReader.podspec

echo ""
echo "Step 4/4: YouVersionPlatform"
publish_pod YouVersionPlatform YouVersionPlatform.podspec

echo ""
echo "✅ Pod version $VERSION is on trunk."
