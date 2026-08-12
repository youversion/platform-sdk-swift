#!/bin/bash
#
# Regenerate or verify the public API baselines used to guard against
# source-breaking changes in the SDK.
#
# Usage:
#   scripts/check-api-stability.sh update   # overwrite baselines in .api-baseline/
#   scripts/check-api-stability.sh check    # diff current API against baselines; non-zero exit on breakage
#   scripts/check-api-stability.sh additions # list new public API grouped by source folder
#   scripts/check-api-stability.sh dump <output-dir>
#                                           # build and dump the public API of all modules into <output-dir>
#   scripts/check-api-stability.sh report <base-dump-dir> <head-dump-dir> [report args...]
#                                           # list public API added between two `dump` outputs (no build);
#                                           # extra args are passed to report-api-additions.py (e.g. --count-file)
#
# If no mode is given, defaults to `check`.

set -euo pipefail

MODE="${1:-check}"

case "$MODE" in
  update|check|additions) ;;
  dump)
    DUMP_OUT="${2:?usage: $0 dump <output-dir>}"
    ;;
  report)
    REPORT_BASE="${2:?usage: $0 report <base-dump-dir> <head-dump-dir> [report args...]}"
    REPORT_HEAD="${3:?usage: $0 report <base-dump-dir> <head-dump-dir> [report args...]}"
    ;;
  *)
    echo "usage: $0 [update|check|additions|dump <output-dir>|report <base-dump-dir> <head-dump-dir>]" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASELINE_DIR="$REPO_ROOT/.api-baseline"
TARGET_TRIPLE="$(uname -m)-apple-macosx15.0"
MODULES=(YouVersionPlatformCore YouVersionPlatformUI YouVersionPlatformReader)

cd "$REPO_ROOT"

if [[ "$MODE" == "report" ]]; then
  shift 3
  exec python3 "$REPO_ROOT/scripts/report-api-additions.py" \
    "$REPORT_BASE" \
    "$REPORT_HEAD" \
    "$REPO_ROOT/Sources" \
    "${MODULES[@]}" \
    "$@"
fi

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

if [[ "$MODE" == "dump" ]]; then
  mkdir -p "$DUMP_OUT"
  for module in "${MODULES[@]}"; do
    # A module absent from this build (e.g. introduced by the PR being diffed)
    # is skipped rather than fatal; the report treats a missing dump as an
    # empty module, so all of its declarations show up as additions.
    if ! ls "$MODULES_DIR/$module.swiftmodule"* >/dev/null 2>&1; then
      echo "Skipping $module: not present in this build." >&2
      continue
    fi
    echo "Dumping $module -> $DUMP_OUT/$module.json"
    dump_module "$module" "$DUMP_OUT/$module.json"
  done
  exit 0
fi

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

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ "$MODE" == "additions" ]]; then
  for module in "${MODULES[@]}"; do
    baseline="$BASELINE_DIR/$module.json"
    current="$WORK_DIR/$module.json"

    if [[ ! -f "$baseline" ]]; then
      echo "Missing baseline for $module at $baseline" >&2
      echo "Run: scripts/check-api-stability.sh update" >&2
      exit 1
    fi

    echo "Dumping $module..."
    dump_module "$module" "$current"
  done

  echo
  python3 "$REPO_ROOT/scripts/report-api-additions.py" \
    "$BASELINE_DIR" \
    "$WORK_DIR" \
    "$REPO_ROOT/Sources" \
    "${MODULES[@]}"
  exit 0
fi

# check mode

FAILED_MODULES=()
TOTAL_BREAKAGES=0

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

  filtered="$WORK_DIR/$module.filtered"
  python3 "$REPO_ROOT/scripts/filter-api-breakages.py" "$diag" "$current" >"$filtered"

  if [[ -s "$filtered" ]]; then
    FAILED_MODULES+=("$module")
    count="$(wc -l < "$filtered" | tr -d ' ')"
    TOTAL_BREAKAGES=$((TOTAL_BREAKAGES + count))
    echo
    echo "  $module: $count breaking change(s) detected"
    sed 's/^API breakage: /    - /' "$filtered"
    echo
  fi
done

if (( ${#FAILED_MODULES[@]} > 0 )); then
  {
    echo
    echo "=============================================================="
    echo " FAILED: public API stability check"
    echo "=============================================================="
    echo "$TOTAL_BREAKAGES breaking change(s) across ${#FAILED_MODULES[@]} module(s): ${FAILED_MODULES[*]}"
    echo
    echo "If these changes are intentional and tied to a major version bump,"
    echo "regenerate the baselines and commit them in the same PR:"
    echo
    echo "  scripts/check-api-stability.sh update"
  } >&2
  exit 1
fi

echo
echo "=============================================================="
echo " PASSED: public API stability check"
echo "=============================================================="
echo "No breaking changes detected in: ${MODULES[*]}"
