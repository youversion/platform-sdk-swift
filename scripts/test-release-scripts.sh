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
echo "release-check-signoff.mjs:"
# The script reads its records on stdin, which the assert helpers do not
# redirect, so wrap it.
# run_signoff <records-json> <version> <current-tag>
run_signoff() {
  local records=$1
  shift
  node scripts/release-check-signoff.mjs "$@" <<<"$records"
}

SIGNED='[{"pr":272,"state":"success","description":"Major v6.0.0 signed off by jhampton."}]'
OTHER_VERSION='[{"pr":9,"state":"success","description":"Major v7.0.0 signed off by jhampton."}]'
PRERELEASE='[{"pr":9,"state":"success","description":"Major v6.0.0-beta.1 signed off by jhampton."}]'
PENDING='[{"pr":9,"state":"pending","description":"Major v6.0.0 signed off by jhampton."}]'
FAILING='[{"pr":9,"state":"failure","description":"Breaking change requires signoff."}]'
BOTH='[{"pr":1,"state":"success","description":"Major v6.0.0 signed off by a."},{"pr":9,"state":"failure","description":"no"}]'
MISSING='[{"pr":1,"state":"success","description":"Major v6.0.0 signed off by a."},{"pr":9,"state":"missing","description":null}]'

assert_exit  0 "major with a signoff naming it → accept"   run_signoff "$SIGNED" 6.0.0 5.5.0
assert_exit  0 "v-prefixed current tag is coerced"         run_signoff "$SIGNED" 6.0.0 v5.5.0
assert_exit  0 "minor bump needs no signoff"               run_signoff '[]' 5.6.0 5.5.0
assert_exit  0 "patch bump needs no signoff"               run_signoff '[]' 5.5.1 5.5.0
assert_exit 21 "major with no signoff at all → block"      run_signoff '[]' 6.0.0 5.5.0
assert_exit 21 "signoff for a different version → block"   run_signoff "$OTHER_VERSION" 6.0.0 5.5.0
assert_exit 21 "prerelease signoff cannot satisfy 6.0.0"   run_signoff "$PRERELEASE" 6.0.0 5.5.0
assert_exit 21 "only a success authorizes, not a pending" run_signoff "$PENDING" 6.0.0 5.5.0
assert_exit 22 "a failing signoff in range → block"        run_signoff "$FAILING" 6.0.0 5.5.0
assert_exit 22 "a failure outranks another PR's success"   run_signoff "$BOTH" 6.0.0 5.5.0
assert_exit 23 "a PR the gate never saw blocks the release" run_signoff "$MISSING" 6.0.0 5.5.0
assert_exit  0 "an unseen PR is fine on a non-major bump"   run_signoff "$MISSING" 5.6.0 5.5.0
assert_exit  1 "non-semver version → usage error"          run_signoff '[]' 6.0 5.5.0
assert_exit  1 "stdin that is not an array → usage error"  run_signoff '{"a":1}' 6.0.0 5.5.0
assert_exit  1 "missing args → usage error"                run_signoff '[]' 6.0.0
assert_stderr_contains "authorized_by=jhampton" "names the approver" run_signoff "$SIGNED" 6.0.0 5.5.0
assert_stderr_contains "not_major"       "minor reports not_major"   run_signoff '[]' 5.6.0 5.5.0
assert_stderr_contains "no_signoff"      "unsigned major reports no_signoff" run_signoff '[]' 6.0.0 5.5.0
assert_stderr_contains "failing_signoff=9" "names the failing PR"    run_signoff "$FAILING" 6.0.0 5.5.0
assert_stderr_contains "missing_signoff=9" "names the unseen PR"     run_signoff "$MISSING" 6.0.0 5.5.0

echo
echo "release.yml wiring (the signoff check is actually invoked):"
# Without this, deleting the step from release.yml would leave every test above
# passing while nothing enforces anything at release time.
if grep -q "scripts/release-check-signoff.mjs" .github/workflows/release.yml; then
  echo "  ✓ release.yml invokes release-check-signoff.mjs"
  PASS=$((PASS + 1))
else
  echo "  ✗ release.yml no longer invokes release-check-signoff.mjs"
  FAIL=$((FAIL + 1))
fi

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
