#!/bin/bash
# Tests for scripts/release-validate.mjs and scripts/release-warn-version-jump.mjs.
#
# Run locally: bash scripts/test-release-scripts.sh
# Run in CI:   wired into .github/workflows/commit-lint.yml so every PR
#              exercises these paths on a different Node version + OS
#              from the release runner (catches argv / shell / Node
#              behavior drift before it reaches a live release).
#
# Why these tests exist:
# - The validation logic used to live inline as `node -e "..."` blocks in
#   release.sh. A code reviewer flagged a (false) concern that
#   `process.argv` indexing under `node -e` was off by one, which would
#   have rejected every valid version. The concern was incorrect for our
#   Node version, but the underlying risk — subtle env-dependent
#   regressions in a code path that only runs at release time — is real.
# - Extracting to standalone .mjs scripts eliminates the inline-eval
#   ambiguity. These tests then guard the extracted logic so any future
#   regression (Node update, semver-package behavior change, refactor)
#   fails loudly at PR time, not at release dispatch.

set -uo pipefail

cd "$(dirname "$0")/.."

PASS=0
FAIL=0

# assert_exit <expected-code> <label> <command...>
# Runs the command, captures stderr+stdout, and asserts the exit code.
assert_exit() {
  local expected=$1
  local label=$2
  shift 2
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ $label (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# assert_stderr_contains <needle> <label> <command...>
# Runs the command and asserts stderr contains the needle substring.
assert_stderr_contains() {
  local needle=$1
  local label=$2
  shift 2
  local err
  err=$("$@" 2>&1 >/dev/null || true)
  if echo "$err" | grep -qF "$needle"; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label (stderr did not contain '$needle'; got: $err)"
    FAIL=$((FAIL + 1))
  fi
}

# assert_stderr_empty <label> <command...>
# Runs the command and asserts stderr is empty.
assert_stderr_empty() {
  local label=$1
  shift
  local err
  err=$("$@" 2>&1 >/dev/null || true)
  if [ -z "$err" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label (expected empty stderr, got: $err)"
    FAIL=$((FAIL + 1))
  fi
}

echo "release-validate.mjs:"
assert_exit  0  "5.2.3 > 5.2.2 → accept"           node scripts/release-validate.mjs 5.2.3 5.2.2
assert_exit  0  "5.3.0 > 5.2.2 → accept"           node scripts/release-validate.mjs 5.3.0 5.2.2
assert_exit  0  "6.0.0 > 5.2.2 → accept"           node scripts/release-validate.mjs 6.0.0 5.2.2
assert_exit  0  "5.2.3 > 0.0.0 → accept (fresh repo)" node scripts/release-validate.mjs 5.2.3 0.0.0
assert_exit 11  "'garbage' is not semver"          node scripts/release-validate.mjs garbage 5.2.2
assert_exit 11  "'5.2' is not semver"              node scripts/release-validate.mjs 5.2 5.2.2
assert_exit 11  "empty version is not semver"      node scripts/release-validate.mjs '' 5.2.2
assert_exit 12  "5.2.2 is not greater than 5.2.2"  node scripts/release-validate.mjs 5.2.2 5.2.2
assert_exit 12  "5.2.1 is not greater than 5.2.2"  node scripts/release-validate.mjs 5.2.1 5.2.2
assert_exit 12  "4.9.9 is not greater than 5.2.2"  node scripts/release-validate.mjs 4.9.9 5.2.2
assert_exit  1  "missing args → usage error"       node scripts/release-validate.mjs 5.2.3
assert_stderr_contains "not_semver"  "rejects with not_semver token"  node scripts/release-validate.mjs garbage 5.2.2
assert_stderr_contains "not_greater" "rejects with not_greater token" node scripts/release-validate.mjs 5.2.1 5.2.2

echo
echo "release-warn-version-jump.mjs:"
# Always exits 0; we assert on stderr presence/absence.
assert_exit  0  "no jump (5.2.3 vs 5.2.2) → exit 0"      node scripts/release-warn-version-jump.mjs 5.2.3 5.2.2
assert_exit  0  "one-major jump (6.0.0 vs 5.2.2) → exit 0" node scripts/release-warn-version-jump.mjs 6.0.0 5.2.2
assert_exit  0  "two-major jump (7.0.0 vs 5.2.2) → exit 0" node scripts/release-warn-version-jump.mjs 7.0.0 5.2.2
assert_exit  0  "invalid calc → silent exit 0"           node scripts/release-warn-version-jump.mjs 5.2.3 unknown
assert_stderr_empty   "no jump prints no warning"           node scripts/release-warn-version-jump.mjs 5.2.3 5.2.2
assert_stderr_empty   "one-major jump prints no warning"    node scripts/release-warn-version-jump.mjs 6.0.0 5.2.2
assert_stderr_contains "more than one major above" "two-major jump prints warning"   node scripts/release-warn-version-jump.mjs 7.0.0 5.2.2
assert_stderr_contains "more than one major above" "three-major jump prints warning" node scripts/release-warn-version-jump.mjs 8.0.0 5.2.2
assert_stderr_empty   "invalid calc is silent"              node scripts/release-warn-version-jump.mjs 5.2.3 unknown

echo
echo "release.sh wiring (no inline node -e):"
# Guard against the inline `node -e` form sneaking back into release.sh.
# The whole point of extracting these scripts was to eliminate the
# ambiguity that reviewers (human or bot) keep flagging.
if grep -nE "^[[:space:]]*node[[:space:]]+-e" scripts/release.sh >/dev/null; then
  echo "  ✗ scripts/release.sh contains inline 'node -e' — extract to a .mjs script"
  grep -nE "^[[:space:]]*node[[:space:]]+-e" scripts/release.sh
  FAIL=$((FAIL + 1))
else
  echo "  ✓ scripts/release.sh has no inline 'node -e'"
  PASS=$((PASS + 1))
fi

echo
if [ "$FAIL" -gt 0 ]; then
  echo "❌ $FAIL test(s) failed out of $((PASS + FAIL))"
  exit 1
else
  echo "✅ All $PASS tests passed"
fi
