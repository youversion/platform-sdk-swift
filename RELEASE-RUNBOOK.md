# Release Runbook

When a dispatched release fails partway, this runbook is the single place to look up the symptom, confirm the actual state, and run the right recovery. It assumes you've read [RELEASING.md](./RELEASING.md) for the normal happy-path flow.

## Recovery cheat sheet

For most partial failures, the answer is **re-dispatch `release.yml` with the same version**. `scripts/release.sh` detects when tag `$VERSION` already exists on origin and enters resume mode: it checks out the tag, regenerates the release notes, and runs the remaining steps idempotently. Each step (`git push`, `gh release create`, Dev-restore) detects already-completed work and skips it.

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

# GitHub release exists?
gh release view "$VERSION" --json name,tagName,createdAt 2>/dev/null || echo "  NO release"
```

The three signals — `tag on origin?`, `main HEAD = X or Y?`, `release exists?` — uniquely identify which phase the original run reached.

---

## Failure modes

### 1. `release.sh` aborted after `git push` but before the GitHub release

**Symptom.** Tag and main are pushed (commit X is on origin/main, tag `$VERSION` is on origin), but the GitHub release does not exist. The original workflow failed in or before `gh release create`.

**State check.** `git ls-remote origin refs/tags/$VERSION` non-empty; `gh release view $VERSION` reports no release.

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. Tag push skipped (already on origin), GH release created, Dev-restore runs.

**Expected end state.** GitHub release exists at `$VERSION`; main HEAD = Y.

---

### 2. `release.sh` aborted after the GitHub release but before Y commit

**Symptom.** The tag and GitHub release exist, but main HEAD is still X (SDKVersion reads `$VERSION`, not `"Dev"`). Original failure was inside `restore-dev-sdk-on-main.sh` — most likely the `git push origin HEAD:main` for Y was rejected (race with an unrelated commit), or the stamping logic hit a file-system error.

This is the most consequential mode to catch, because nothing downstream fails loudly: the next release aborts early with `SDKVersion.swift does not currently read "Dev"`, and until then in-repo builds report a stale released version to telemetry.

**State check.** `git log origin/main -1 --format='%s'` reads `chore(release): $VERSION [skip ci]` (X), not `chore(release): restore SDKVersion to Dev after $VERSION [skip ci]` (Y).

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. All earlier steps are no-ops; `restore-dev-sdk-on-main.sh` runs and creates Y.

**Expected end state.** main HEAD = Y with SDKVersion reading `"Dev"`.

---

### 3. Y push fails because main diverged

**Symptom.** Same as #4, but the Dev-restore script aborts with a non-fast-forward push error because someone landed an unrelated commit on `main` between the X push and the Y push.

**State check.** `git log origin/main -5 --format='%h %s'` — you'll see X then an unrelated commit on top of it. No Y yet.

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. Resume mode now finds origin/main has advanced past X, skips the main push, fetches the latest main, and lets `restore-dev-sdk-on-main.sh` create Y on top of the new main HEAD. If that push also fails (yet another commit landed), repeat.

If repeated divergence is making this loop, drain the inbox or pause merges to main for a few minutes, then re-dispatch.

**Expected end state.** main HEAD = Y on top of the latest main (which now includes the unrelated commit and X is reachable via the new Y → previous main HEAD → X path).

---

### 4. `gh release create` fails after tag is pushed

**Symptom.** Tag is on origin, main is on origin, no GitHub release on the Releases page, the workflow log shows `gh release create` failed (rate limit, transient API error, token scope).

**State check.** `gh release view $VERSION` returns non-zero. `git ls-remote origin refs/tags/$VERSION` non-empty.

**Recovery.** Re-dispatch `release.yml -f version=$VERSION`. The idempotent `if gh release view ... else create` block creates the release using regenerated notes. The rest of the pipeline continues.

**Expected end state.** GitHub release `$VERSION` visible on the Releases page; main HEAD = Y.

---

### 5. Tag exists on origin but the tree doesn't match `$VERSION` (rogue tag)

**Symptom.** Re-dispatched `release.yml` exits with:

```
❌ Tag $VERSION exists but its tree's SDKVersion.swift does not read "$VERSION".
```

This means someone created or moved the tag manually, or the tag is a leftover from a different process.

**State check.** `git show refs/tags/$VERSION:Sources/YouVersionPlatformCore/SDKVersion.swift | grep current`. The value won't match `$VERSION`.

**Recovery.** **Do not auto-heal.** Decide deliberately:

- If the rogue tag is a true mistake (e.g. test tag named after a real version), delete it: `git push origin --delete $VERSION`, also delete any GitHub release attached to it, then dispatch `release.yml -f version=$VERSION` fresh.
- If the rogue tag points at a legitimate release commit that just isn't in the expected format (e.g. an older release scheme), don't reuse this VERSION at all — bump to the next semver and dispatch that.

**Expected end state.** Either fresh-shipped at `$VERSION` (if you deleted the rogue tag) or shipped at a new version.

---

### 6. Wrong VERSION input (less than current, invalid semver)

**Symptom.** `release.sh` exits during validation with `'X' is not valid semver` or `'X' is not strictly greater than current tag 'Y'`. This is _not_ a recovery scenario — it's a pre-flight catch.

**State check.** None needed. Workflow log shows the exit reason.

**Recovery.** Dispatch with a valid, strictly-greater semver.

(Note: if the version you typed _equals_ the current tag, the script enters resume mode rather than failing. The "not strictly greater" check is suppressed in resume mode because re-dispatching with the same version is the resume gesture.)

---

### 7. SSH push key rejected

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
