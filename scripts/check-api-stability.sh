#!/bin/bash
#
# Regenerate or verify the public API baselines used to guard against
# source-breaking changes in the SDK.
#
# Usage:
#   scripts/check-api-stability.sh update   # overwrite baselines in .api-baseline/
#   scripts/check-api-stability.sh check    # diff current API against baselines; non-zero exit on breakage
#
# If no mode is given, defaults to `check`.

set -euo pipefail

MODE="${1:-check}"

if [[ "$MODE" != "update" && "$MODE" != "check" ]]; then
  echo "usage: $0 [update|check]" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASELINE_DIR="$REPO_ROOT/.api-baseline"
TARGET_TRIPLE="arm64-apple-macosx15.0"
MODULES=(YouVersionPlatformCore YouVersionPlatformUI YouVersionPlatformReader)

cd "$REPO_ROOT"

echo "Building package for API digest..."
swift build -c release >/dev/null

BIN_PATH="$(swift build -c release --show-bin-path)"
MODULES_DIR="$BIN_PATH/Modules"

if [[ ! -d "$MODULES_DIR" ]]; then
  echo "Expected modules directory not found: $MODULES_DIR" >&2
  exit 1
fi

dump_module() {
  local module="$1"
  local output="$2"
  xcrun swift-api-digester \
    -dump-sdk \
    -avoid-location \
    -avoid-tool-args \
    -module "$module" \
    -I "$MODULES_DIR" \
    -target "$TARGET_TRIPLE" \
    -o "$output"
}

if [[ "$MODE" == "update" ]]; then
  mkdir -p "$BASELINE_DIR"
  for module in "${MODULES[@]}"; do
    echo "Dumping $module -> .api-baseline/$module.json"
    dump_module "$module" "$BASELINE_DIR/$module.json"
  done
  echo
  echo "Baselines updated. Review the diff and commit the changes."
  exit 0
fi

# check mode
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

FAILED_MODULES=()

for module in "${MODULES[@]}"; do
  baseline="$BASELINE_DIR/$module.json"
  current="$WORK_DIR/$module.json"
  diag="$WORK_DIR/$module.diag"

  if [[ ! -f "$baseline" ]]; then
    echo "Missing baseline for $module at $baseline" >&2
    echo "Run: scripts/check-api-stability.sh update" >&2
    exit 1
  fi

  echo "Checking $module..."
  dump_module "$module" "$current"

  xcrun swift-api-digester \
    -diagnose-sdk \
    -compiler-style-diags \
    -input-paths "$baseline" \
    -input-paths "$current" \
    >"$diag" 2>&1 || true

  if grep -q "^API breakage:" "$diag"; then
    FAILED_MODULES+=("$module")
    echo
    echo "=== Breaking changes detected in $module ==="
    grep "^API breakage:" "$diag"
    echo
  fi
done

if (( ${#FAILED_MODULES[@]} > 0 )); then
  echo "API stability check failed for: ${FAILED_MODULES[*]}" >&2
  echo
  echo "If these changes are intentional and tied to a major version bump, run:" >&2
  echo "  scripts/check-api-stability.sh update" >&2
  echo "then commit the updated baseline files." >&2
  exit 1
fi

echo "API stability check passed."
