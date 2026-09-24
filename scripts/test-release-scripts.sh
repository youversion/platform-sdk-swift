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

# The gate posts as the Actions bot; `record <pr> <state> <description>` builds a
# record with that provenance, and the odd ones out override it explicitly.
record() { printf '{"pr":%s,"state":"%s","description":%s,"creator":"github-actions[bot]","creator_type":"Bot"}' "$1" "$2" "$3"; }
GATE_OK=$(record 1 success '"Major v6.0.0 signed off by jhampton."')

SIGNED="[$(record 272 success '"Major v6.0.0 signed off by jhampton."')]"
OTHER_VERSION="[$(record 9 success '"Major v7.0.0 signed off by jhampton."')]"
PRERELEASE="[$(record 9 success '"Major v6.0.0-beta.1 signed off by jhampton."')]"
PENDING="[$(record 9 pending '"Major v6.0.0 signed off by jhampton."')]"
FAILING="[$(record 9 failure '"Breaking change requires signoff."')]"
BOTH="[$GATE_OK,$(record 9 failure '"no"')]"
MISSING="[$GATE_OK,$(record 9 missing null)]"
# Cam's two: a gate-passed range must be entirely success, and a status the gate
# did not write must not authorize anything.
SIGNED_PLUS_PENDING="[$GATE_OK,$(record 9 pending '"awaiting signoff"')]"
SIGNED_PLUS_ERROR="[$GATE_OK,$(record 9 error '"boom"')]"
FREEFORM="[$(record 1 success '"v6.0.0"')]"
HUMAN_POSTED='[{"pr":1,"state":"success","description":"Major v6.0.0 signed off by jhampton.","creator":"Kyleasmth","creator_type":"User"}]'

assert_exit  0 "major with a signoff naming it → accept"   run_signoff "$SIGNED" 6.0.0 5.5.0
assert_exit  0 "v-prefixed current tag is coerced"         run_signoff "$SIGNED" 6.0.0 v5.5.0
assert_exit  0 "minor bump needs no signoff"               run_signoff '[]' 5.6.0 5.5.0
assert_exit  0 "patch bump needs no signoff"               run_signoff '[]' 5.5.1 5.5.0
assert_exit  1 "major with no signoff at all → block"       run_signoff '[]' 6.0.0 5.5.0
assert_exit  1 "signoff for a different version → block"    run_signoff "$OTHER_VERSION" 6.0.0 5.5.0
assert_exit  1 "prerelease signoff cannot satisfy 6.0.0"    run_signoff "$PRERELEASE" 6.0.0 5.5.0
assert_exit  1 "only a success authorizes, not a pending"   run_signoff "$PENDING" 6.0.0 5.5.0
assert_exit  1 "a failing signoff in range → block"         run_signoff "$FAILING" 6.0.0 5.5.0
assert_exit  1 "a failure outranks another PR's success"    run_signoff "$BOTH" 6.0.0 5.5.0
assert_exit  1 "a PR the gate never saw blocks the release" run_signoff "$MISSING" 6.0.0 5.5.0
# The resume path: release.sh dispatches the version that is already tagged, so a
# base of $VERSION would read every major as no bump and skip the check entirely.
assert_exit  1 "the requested version as its own base is refused" run_signoff '[]' 6.0.0 6.0.0
assert_stderr_contains "is not older than" "…and says the base is wrong" run_signoff '[]' 6.0.0 6.0.0
assert_exit  1 "a pending PR blocks even with another signed"  run_signoff "$SIGNED_PLUS_PENDING" 6.0.0 5.5.0
assert_exit  1 "an errored PR blocks even with another signed" run_signoff "$SIGNED_PLUS_ERROR" 6.0.0 5.5.0
assert_exit  1 "free-form text naming the version is not a signoff" run_signoff "$FREEFORM" 6.0.0 5.5.0
assert_exit  1 "the exact sentence posted by a human is refused"    run_signoff "$HUMAN_POSTED" 6.0.0 5.5.0
assert_exit  0 "an unseen PR is fine on a non-major bump"    run_signoff "$MISSING" 5.6.0 5.5.0
assert_exit  1 "non-semver version → usage error"           run_signoff '[]' 6.0 5.5.0
assert_exit  1 "stdin that is not an array → usage error"   run_signoff '{"a":1}' 6.0.0 5.5.0
assert_exit  1 "missing args → usage error"                 run_signoff '[]' 6.0.0
assert_stderr_contains "authorized by jhampton" "names the approver" run_signoff "$SIGNED" 6.0.0 5.5.0
assert_stderr_contains "not a major bump"  "minor says so"           run_signoff '[]' 5.6.0 5.5.0
assert_stderr_contains "no PR merged since 5.5.0" "unsigned major names the base" run_signoff '[]' 6.0.0 5.5.0
assert_stderr_contains "status of 'failure'" "names the failing PR" run_signoff "$FAILING" 6.0.0 5.5.0
assert_stderr_contains "PR #9 has no major-release-signoff" "names the unseen PR" run_signoff "$MISSING" 6.0.0 5.5.0
assert_stderr_contains "status of 'pending'" "names the unresolved state" run_signoff "$SIGNED_PLUS_PENDING" 6.0.0 5.5.0
assert_stderr_contains "gate-issued"  "says the signoff must come from the gate" run_signoff "$FREEFORM" 6.0.0 5.5.0

# release-check-signoff.mjs parses the status description to authorize a release.
# The tests above feed it hand-written copies of that format, so rewording the
# workflow would block every future major while the suite stayed green.
DESCRIPTION_WRITER='description="Major v${NEXT_VERSION} signed off by ${APPROVER}."'
if grep -qF "$DESCRIPTION_WRITER" .github/workflows/major-release-signoff.yml; then
  echo "  ✓ the gate still writes the description release-check-signoff.mjs parses"
  PASS=$((PASS + 1))
else
  echo "  ✗ the gate's status description changed; release-check-signoff.mjs cannot parse it"
  FAIL=$((FAIL + 1))
fi

echo
echo "release.sh wiring (the signoff check is actually invoked):"
# Without this, deleting the step from release.yml would leave every test above
# passing while nothing enforces anything at release time.
if grep -q "scripts/release-check-signoff.mjs" scripts/release.sh; then
  echo "  ✓ release.sh invokes release-check-signoff.mjs"
  PASS=$((PASS + 1))
else
  echo "  ✗ release.sh no longer invokes release-check-signoff.mjs"
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
