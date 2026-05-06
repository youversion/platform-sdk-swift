#!/bin/bash
# Stamp a version string into Sources/YouVersionPlatformCore/SDKVersion.swift.
#
# Idempotent: works whether the file currently reads "Dev" or any prior
# version string. Replaces the value between the double-quotes on the
# `static let current = "..."` line.
#
# Designed to be portable to other YouVersion SDKs that use semantic-release:
# the only project-specific bits are the FILE path and the line marker.
set -e

cd "$(dirname "$0")/.."

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Error: Version parameter is required"
  exit 1
fi

FILE="Sources/YouVersionPlatformCore/SDKVersion.swift"

if [ ! -f "$FILE" ]; then
  echo "Error: $FILE not found"
  exit 1
fi

echo "Stamping SDK version $VERSION into $FILE..."

# Replace the literal between quotes on the `static let current = "..."` line.
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/static let current = \"[^\"]*\"/static let current = \"$VERSION\"/" "$FILE"
else
  sed -i "s/static let current = \"[^\"]*\"/static let current = \"$VERSION\"/" "$FILE"
fi

if ! grep -q "static let current = \"$VERSION\"" "$FILE"; then
  echo "Error: Failed to stamp version into $FILE"
  exit 1
fi

echo "  ✓ $FILE now reads: $(grep 'static let current' "$FILE" | sed 's/^[[:space:]]*//')"
echo "SDK version stamp complete."
