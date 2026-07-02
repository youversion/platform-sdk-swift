# Release Runbook

When a dispatched release fails partway, this runbook is the single place to look up the symptom, confirm the actual state, and run the right recovery. It assumes you've read [RELEASING.md](./RELEASING.md) for the normal happy-path flow.

## Recovery cheat sheet

For most partial failures, the answer is **re-dispatch `release.yml` with the same version**. `scripts/release.sh` detects when tag `$VERSION` already exists on origin and enters resume mode: it checks out the tag, regenerates the release notes, and runs the remaining steps idempotently. Each step (`git push`, `gh release create`, `pod trunk push`, Dev-restore) detects already-completed work and skips it.

```bash
gh workflow run release.yml -f version=<the same version that just failed>
```

The exceptions — where you should _not_ just re-dispatch — are listed under "When re-dispatch is unsafe" at the bottom.

## State to check before recovering

Run these commands on a fresh clone (or `cd` into the repo and `git fetch --tags origin`):

```bash
VERSION=<the version>

# Tag on origin?
git ls-remote origin "refs/tags/$VERSION"

# Local main HEAD: X (release commit) or Y (Dev-restore)?
git log origin/main -2 --format='%h %s'

# Pods on trunk?
for p in YouVersionPlatformCore YouVersionPlatformUI YouVersionPlatformReader YouVersionPlatform; do
  echo "== $p =="
  pod trunk info "$p" 2>/dev/null | grep -E "^[[:space:]]+- $VERSION " || echo "  NOT on trunk"
done

# GitHub release exists?
gh release view "$VERSION" --json name,tagName,createdAt 2>/dev/null || echo "  NO release"
```

The four signals — `tag on origin?`, `main HEAD = X or Y?`, `pods on trunk?`, `release exists?` — uniquely identify which phase the original run reached.

---

## Failure modes

### 1. `pod trunk push` fails with "Calling the GitHub commit API timed out"

**Symptom.** During `publish-pods.sh`, one of the four `pod trunk push` calls exits non-zero after several minutes with `[!] Calling the GitHub commit API timed out`. Trunk's xcodebuild validation succeeded; trunk's internal call to GitHub's commit API timed out.

**Example.** [Workflow run 26537791362](https://github.com/youversion/platform-sdk-swift/actions/runs/26537791362) for 5.2.3 (2026-05-27). Got to step 1/4 (Core), trunk validated, then GitHub API timeout.

**State check.** `pod trunk info <Pod>` will either show the version (trunk accepted before the timeout — partial success) or not show it (trunk never recorded the publish). Both are possible from the same error.

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. Resume mode engages, the per-pod `pod_already_published` check skips anything trunk did record, and `publish-pods.sh` retries the failed pod once with a 30s backoff before continuing. If both attempts on the same pod fail, the script exits — re-dispatch again (the second dispatch's already-published check will recognise anything that did land in the meantime).

**Expected end state.** All four pods at `$VERSION` on trunk; main HEAD = Y (Dev-restore).

---

### 2. Partial pod publish (some pods on trunk, others not)

**Symptom.** `pod trunk info` shows `$VERSION` for some pods but not others. Can result from #1, from CDN-propagation lag between dependent pushes, or from any other mid-publish failure.

**State check.** `pod trunk info` for each of Core, UI, Reader, Platform.

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. Published pods are skipped via `pod trunk info`; missing pods are pushed in dependency order.

Alternative if you don't want the rest of the release pipeline to re-run (e.g. you want to skip Dev-restore): dispatch `manual-pod-publish.yml -f version=$VERSION -f restore_dev=false`. That workflow only runs `publish-pods.sh`.

**Expected end state.** All four pods at `$VERSION` on trunk.

---

### 3. `release.sh` aborted after `git push` but before pod publish

**Symptom.** Tag and main are pushed (commit X is on origin/main, tag `$VERSION` is on origin), GitHub release may or may not exist, but no pods are on trunk. The original workflow failed in `gh release create` or before `publish-pods.sh`.

**State check.** `git ls-remote origin refs/tags/$VERSION` non-empty; `gh release view $VERSION`; `pod trunk info`.

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. Tag push skipped (already on origin), GH release created or skipped (idempotent), pods published, Dev-restore runs.

**Expected end state.** All four pods at `$VERSION` on trunk; main HEAD = Y.

---

### 4. `release.sh` aborted after pod publish but before Y commit

**Symptom.** All four pods at `$VERSION` on trunk, but main HEAD is still X (SDKVersion reads `$VERSION`, not `"Dev"`). Original failure was inside `restore-dev-sdk-on-main.sh` — most likely the `git push origin HEAD:main` for Y was rejected (race with an unrelated commit), or the stamping logic hit a file-system error.

**State check.** `git log origin/main -1 --format='%s'` reads `chore(release): $VERSION [skip ci]` (X), not `chore(release): restore SDKVersion to Dev after $VERSION [skip ci]` (Y). `pod trunk info` shows all four pods at `$VERSION`.

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. All earlier steps are no-ops; `restore-dev-sdk-on-main.sh` runs and creates Y.

**Expected end state.** main HEAD = Y with SDKVersion reading `"Dev"`.

---

### 5. Y push fails because main diverged

**Symptom.** Same as #4, but the Dev-restore script aborts with a non-fast-forward push error because someone landed an unrelated commit on `main` between the X push and the Y push.

**State check.** `git log origin/main -5 --format='%h %s'` — you'll see X then an unrelated commit on top of it. No Y yet.

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. Resume mode now finds origin/main has advanced past X, skips the main push, fetches the latest main, and lets `restore-dev-sdk-on-main.sh` create Y on top of the new main HEAD. If that push also fails (yet another commit landed), repeat.

If repeated divergence is making this loop, drain the inbox or pause merges to main for a few minutes, then re-dispatch.

**Expected end state.** main HEAD = Y on top of the latest main (which now includes the unrelated commit and X is reachable via the new Y → previous main HEAD → X path).

---

### 6. `gh release create` fails after tag is pushed

**Symptom.** Tag is on origin, main is on origin, no GitHub release on the Releases page, the workflow log shows `gh release create` failed (rate limit, transient API error, token scope).

**State check.** `gh release view $VERSION` returns non-zero. `git ls-remote origin refs/tags/$VERSION` non-empty.

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. The idempotent `if gh release view ... else create` block creates the release using regenerated notes. The rest of the pipeline continues.

**Expected end state.** GitHub release `$VERSION` visible on the Releases page; pods on trunk; main HEAD = Y.

---

### 7. Tag exists on origin but the tree doesn't match `$VERSION` (rogue tag)

**Symptom.** Re-dispatched `release.yml` exits with:

```
❌ Tag $VERSION exists but its tree's SDKVersion.swift does not read "$VERSION".
```

Or the equivalent for a podspec. This means someone created or moved the tag manually, or the tag is a leftover from a different process.

**State check.** `git show refs/tags/$VERSION:Sources/YouVersionPlatformCore/SDKVersion.swift | grep current` and the four podspecs. The values won't match `$VERSION`.

**Recovery.** **Do not auto-heal.** Decide deliberately:

- If the rogue tag is a true mistake (e.g. test tag named after a real version), delete it: `git push origin --delete $VERSION`, also delete any GitHub release attached to it, then dispatch `release.yml -f version=$VERSION` fresh.
- If the rogue tag points at a legitimate release commit that just isn't in the expected format (e.g. an older release scheme), don't reuse this VERSION at all — bump to the next semver and dispatch that.

**Expected end state.** Either fresh-shipped at `$VERSION` (if you deleted the rogue tag) or shipped at a new version.

---

### 8. Wrong VERSION input (less than current, invalid semver)

**Symptom.** `release.sh` exits during validation with `'X' is not valid semver` or `'X' is not strictly greater than current tag 'Y'`. This is _not_ a recovery scenario — it's a pre-flight catch.

**State check.** None needed. Workflow log shows the exit reason.

**Recovery.** Dispatch with a valid, strictly-greater semver.

(Note: if the version you typed _equals_ the current tag, the script enters resume mode rather than failing. The "not strictly greater" check is suppressed in resume mode because re-dispatching with the same version is the resume gesture.)

---

### 9. Trunk session expired (`COCOAPODS_TRUNK_TOKEN` invalid)

**Symptom.** `publish-pods.sh` fails on the first attempt with `Authentication token` or `not authorized`. The retry policy classifies these as hard-fail and does not retry.

**State check.** Run `pod trunk me` with the token to confirm: `COCOAPODS_TRUNK_TOKEN=<token> pod trunk me`. If it says the token is invalid or expired, that's the cause.

**Recovery.**

1. Regenerate a trunk session token (locally, with a privileged trunk account): `pod trunk register support@youversion.com 'CI' --description='CI release token'`. Confirm the email, then `pod trunk me --verbose` shows the token in `~/.netrc`.
2. Update the repo's `COCOAPODS_TRUNK_TOKEN` secret with the new value.
3. Re-dispatch `release.yml -f version=$VERSION`. Resume mode picks up where it left off.

**Expected end state.** Pods publish; release completes.

---

### 10. SSH push key rejected

**Symptom.** Workflow fails on `git push origin HEAD:main` or `git push origin $VERSION` with permission denied. Usually means the deploy key was rotated, removed, or had write access disabled.

**State check.** `https://github.com/youversion/platform-sdk-swift/settings/keys` — the deploy key matching the `RELEASE_SSH_KEY` secret should be listed with write access.

**Recovery.**

1. Generate a new SSH key pair (see [RELEASING.md → RELEASE_SSH_KEY](./RELEASING.md#1-release_ssh_key)).
2. Add the public key as a Deploy Key with write access.
3. Update the `RELEASE_SSH_KEY` secret with the new private key.
4. Re-dispatch `release.yml -f version=$VERSION`. If the tag was already pushed before the failure, resume mode picks up; otherwise this runs as fresh.

**Expected end state.** Pushes succeed; release completes.

---

## When re-dispatch is unsafe

Re-dispatching `release.yml -f version=$VERSION` is the standard recovery for almost everything. Don't re-dispatch when:

- The original failure was a **rogue tag** (#7): re-dispatch will exit immediately with a tag-content-mismatch error. Resolve the tag first.
- The original failure was **wrong input** (#8): dispatch with a corrected version, not the wrong one.
- You need to **change what's being released** (different commits, different notes): the tag is immutable from the release's perspective. Cut a new version.

For everything else, re-dispatching is the right answer. The script's idempotency checks will skip whatever already succeeded.

## Emergency: release by hand without the workflow

If the workflow itself is broken (e.g. GitHub Actions outage, runner pool exhausted), `scripts/release.sh` can be invoked locally with the same environment variables. See [RELEASING.md → Need an emergency release without the workflow](./RELEASING.md#need-an-emergency-release-without-the-workflow).
