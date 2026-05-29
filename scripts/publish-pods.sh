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

# Wraps `pod trunk push` in a bounded retry loop.
#
# Why retry at all: trunk's "Calling the GitHub commit API timed out" failure
# (workflow run 26537791362, 2026-05-27) is upstream weather. The trunk service
# accepts the spec, then calls GitHub to commit the change to the Specs repo;
# if that call times out, the whole `pod trunk push` exits non-zero — sometimes
# after trunk has actually accepted, sometimes before.
#
# Why only 2 attempts: each `pod trunk push` runs trunk-side xcodebuild (~9–18
# min). Three attempts can blow past the 6h job ceiling once all four pods are
# stacked. Two attempts plus safe-re-dispatch (release.sh resume mode) is the
# correct division — the workflow is the outer retry loop.
#
# Why pre-check `pod_already_published` on every iteration: partial-success.
# Trunk may have accepted before the GH-API call failed, so the second attempt
# could otherwise re-upload (and trunk would reject as duplicate, masking the
# real success).
publish_pod_with_retry() {
  local pod_name="$1"
  local podspec="$2"
  local max_attempts=2
  local attempt=1
  local out
  while [ "$attempt" -le "$max_attempts" ]; do
    if pod_already_published "$pod_name" "$VERSION"; then
      echo "  ✓ $pod_name $VERSION on trunk (attempt $attempt) — skipping"
      return 0
    fi

    out=$(mktemp)
    # Don't let pipefail kill us before we read $out — we want to inspect the
    # exit code ourselves so we can classify transient vs hard failure.
    set +e
    pod trunk push "$podspec" --allow-warnings --synchronous 2>&1 | tee "$out"
    local push_status=${PIPESTATUS[0]}
    set -e

    if [ "$push_status" -eq 0 ]; then
      rm -f "$out"
      return 0
    fi

    # Trunk may have accepted the spec before the GH-API call timed out.
    # Re-check before classifying as failure.
    if pod_already_published "$pod_name" "$VERSION"; then
      echo "  ✓ $pod_name $VERSION on trunk despite non-zero exit (attempt $attempt)"
      rm -f "$out"
      return 0
    fi

    # Hard-fail signatures — auth, validation, bad spec. No point retrying.
    if grep -qE "Authentication token|not authorized|invalid podspec|^\[!\] The .* validator|ERROR \|" "$out"; then
      echo "  ✗ $pod_name: non-retryable failure on attempt $attempt"
      rm -f "$out"
      return 1
    fi

    # Transient signatures — upstream timeout, network blip, 5xx.
    if [ "$attempt" -lt "$max_attempts" ] && \
       grep -qE "timed out|timeout|50[234]|temporarily unavailable|Could not resolve host|Connection reset|RPC failed" "$out"; then
      echo "  ⚠ $pod_name: transient trunk failure on attempt $attempt — sleeping 30s and retrying"
      sleep 30
      rm -f "$out"
      attempt=$((attempt + 1))
      continue
    fi

    # Unclassified failure — don't retry blind. Surface the output to the log.
    echo "  ✗ $pod_name: unclassified failure on attempt $attempt"
    rm -f "$out"
    return 1
  done
  return 1
}

echo "Publishing version $VERSION to CocoaPods trunk..."
echo "IMPORTANT: Pods will be published in dependency order; already-published versions are skipped"

echo ""
echo "Step 1/4: YouVersionPlatformCore"
publish_pod_with_retry YouVersionPlatformCore YouVersionPlatformCore.podspec

echo ""
echo "Step 2/4: YouVersionPlatformUI"
publish_pod_with_retry YouVersionPlatformUI YouVersionPlatformUI.podspec

echo ""
echo "Step 3/4: YouVersionPlatformReader"
publish_pod_with_retry YouVersionPlatformReader YouVersionPlatformReader.podspec

echo ""
echo "Step 4/4: YouVersionPlatform"
publish_pod_with_retry YouVersionPlatform YouVersionPlatform.podspec

echo ""
echo "✅ Pod version $VERSION is on trunk."
