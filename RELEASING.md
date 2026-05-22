# Release Process

Releases on this repo are **manually triggered with an explicit version input**. A human types the version they want to publish into the Actions UI (or `gh workflow run`), the workflow validates it, and the release ships. There is no auto-release on merges to `main`.

## Overview

The release pipeline does not use `semantic-release` as an orchestrator. We use two pieces of it as libraries:

- [`@semantic-release/commit-analyzer`](https://github.com/semantic-release/commit-analyzer) — invoked by `scripts/preview-release.mjs` to compute what version the commits *would* suggest (shown in the PR's Commit Lint comment and in the release workflow's job summary for audit).
- [`@semantic-release/release-notes-generator`](https://github.com/semantic-release/release-notes-generator) — invoked by `scripts/generate-release-notes.mjs` to render the CHANGELOG entry and GitHub release body from commits since the last tag.

Everything else (validation, version stamping, podspec updates, commit, tag, push, GitHub release creation, pod publish, Dev-restore) is in `scripts/release.sh`, which the release workflow calls directly.

This split exists because `semantic-release`'s lifecycle tightly couples computation to execution. There is no hook to override its calculated version — the only way to ship a version that differs from what the analyzer computes is to commit-message-engineer history, which is brittle, slow, and unreviewable. By making the version an explicit workflow input we get one-click overrides, a side-by-side audit log of "calculator said X, human chose Y," and no history rewrites.

## How It Works

1. **Develop on a branch with conventional commit subjects.** The `Commit Lint` workflow validates every PR and previews the version the analyzer would compute.
2. **Merge PRs to `main`.** Nothing publishes. `main` just accumulates work.
3. **Decide on a version.** The most recent merged PR's Commit Lint comment shows the analyzer-computed value, which is the suggested next version. You can accept that or override.
4. **Dispatch the Release workflow** from the Actions tab → `Release` → "Run workflow", or via CLI:
   ```bash
   gh workflow run release.yml -f version=5.3.0
   ```
   To validate the workflow end-to-end on a feature branch without shipping, also pass `-f dry-run=true`.
5. **The workflow runs `scripts/release.sh`**, which:
   - Validates the input is valid semver and strictly greater than the current tag.
   - Logs the calculator's computed value alongside the chosen value in the job summary.
   - Warns (but does not block) if the chosen version is more than one major above calculated.
   - Generates release notes from commits since the last tag.
   - Prepends the new entry to `CHANGELOG.md`.
   - Stamps `SDKVersion.swift` and all four podspecs to the chosen version.
   - Commits everything as `chore(release): <version> [skip ci]` (commit **X**), with the release notes embedded as the commit body.
   - Tags **X** with the version and pushes both to `main`.
   - Creates a GitHub release with the generated notes.
   - Publishes all four pods to CocoaPods trunk in dependency order.
   - Creates a follow-up commit **Y** that restores `SDKVersion.swift` to `"Dev"` on `main`, so subsequent dev/CI builds don't report a stale released version. The tag stays at **X** (which is reachable from `main` via Y → X).

## Required GitHub Configuration

### GitHub Secrets

The following secrets must be configured in the repository:

#### 1. `RELEASE_SSH_KEY`

An SSH private key used to bypass the `main` branch-protection ruleset so the release workflow can push commits **X** and **Y** and the version tag.

1. Generate an SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-release" -f release_key -N ""
   ```
2. Add the **public key** (`release_key.pub`) as a Deploy Key at `https://github.com/youversion/platform-sdk-swift/settings/keys`:
   - Title: `release` (or your preferred name)
   - Paste contents of `release_key.pub`
   - **Check "Allow write access"** ✓
3. Add the **private key** (`release_key`) as a repository secret at `https://github.com/youversion/platform-sdk-swift/settings/secrets/actions`:
   - Name: `RELEASE_SSH_KEY`
   - Value: paste entire contents of the `release_key` file

> **Important:** the secret name `RELEASE_SSH_KEY` must match the reference in `.github/workflows/release.yml`. If you rename the secret, update the workflow too.

#### 2. `COCOAPODS_TRUNK_TOKEN`

Your CocoaPods trunk session token, used by `scripts/publish-pods.sh` to authenticate the `pod trunk push` calls.

```bash
# Get your token from ~/.netrc after registering
cat ~/.netrc | grep cocoapods.org
```

Or:

```bash
pod trunk me
```

Add the token to repository secrets as `COCOAPODS_TRUNK_TOKEN`.

### Branch Protection Configuration

The `main` branch ruleset requires pull requests, but the release workflow needs to push **X** and **Y** commits and the tag directly. The Deploy Key configured above bypasses this.

1. Go to `https://github.com/youversion/platform-sdk-swift/settings/rules`
2. Edit the ruleset for `main`
3. Under "Bypass list", ensure "Deploy keys" is enabled

## Local Testing

### Preview the version the analyzer would suggest

```bash
node scripts/preview-release.mjs \
  --base "$(git describe --tags --abbrev=0)" \
  --head HEAD
```

Outputs JSON: `{"current": "5.2.2", "next": "5.2.3", "release_type": "patch", ...}`. The same logic the `Commit Lint` workflow uses on every PR.

### Generate release notes for a hypothetical version

```bash
node scripts/generate-release-notes.mjs \
  --base "$(git describe --tags --abbrev=0)" \
  --head HEAD \
  --version 5.2.3
```

Prints the markdown that would be prepended to `CHANGELOG.md` and used as the GitHub release body.

### Dry-run the full release end-to-end

```bash
VERSION=5.2.3 DRY_RUN=1 SKIP_LINT=1 bash scripts/release.sh
```

Validates the version, generates notes, updates `CHANGELOG.md` and podspecs, stamps `SDKVersion.swift`, builds commit X, tags it — then stops without pushing. `SKIP_LINT=1` bypasses the `pod lib lint` step which needs Xcode + iOS simulator runtime (CI has it; most dev machines don't).

Clean up after a dry-run:

```bash
git reset --hard HEAD^
git tag -d <version>
git restore .
rm -f notes.md
```

### Test commitlint

```bash
# Lint every commit on your branch that isn't on main
npx commitlint --from=origin/main --to=HEAD --verbose

# Or, equivalently:
npm run commitlint

# Pipe a single message to test rule changes
echo "feat: add new feature" | npx commitlint
echo "invalid message" | npx commitlint   # should fail
```

## Version Synchronization

All four podspecs are kept in sync via `scripts/update-pod-versions.sh`:

- `YouVersionPlatformCore.podspec`
- `YouVersionPlatformUI.podspec` (depends on Core)
- `YouVersionPlatformReader.podspec` (depends on UI)
- `YouVersionPlatform.podspec` (umbrella, depends on all)

Inter-pod dependencies use `s.version.to_s`, so a single version-bump call updates everything coherently.

## Publishing Order

Pods are published in dependency order by `scripts/publish-pods.sh`:

1. **YouVersionPlatformCore** (no dependencies)
2. **YouVersionPlatformUI** (depends on Core)
3. **YouVersionPlatformReader** (depends on UI)
4. **YouVersionPlatform** (umbrella, depends on all)

`pod trunk push` is non-idempotent and can partial-succeed: a network blip can leave Core published but UI not. The script checks `pod trunk info <PodName>` for the target version before each push, so re-running on the same version is safe.

## Troubleshooting

### The Commit Lint preview shows a major bump on a "patch" PR

`conventional-commits-parser` treats `BREAKING CHANGE` at the start of any commit body line as a breaking-change footer, regardless of surrounding markdown or quotes. The most common cause: a long commit body wraps and a paragraph happens to start with that token. Reword the offending line on your branch.

The analyzer log in the PR comment's `<details>` block shows which commit triggered the classification.

### The release dispatch is rejected with "is not strictly greater than current tag"

`release.sh` refuses to ship a version less than or equal to the latest tag. If you genuinely need to re-tag (e.g., recovering from a partial release), delete the old tag from origin first, then dispatch again.

### CocoaPods publish failed midway

The script is idempotent via `pod trunk info`. Re-dispatch with the same version; the already-published pods will be skipped and the missing ones retried. If `pod trunk info` itself is unreliable, check `pod trunk me` to confirm authentication.

### The release script aborted after pushing the tag — main is stamped with the released version

If `release.sh` dies in any of the post-push steps (`gh release create`, `publish-pods.sh`, `restore-dev-sdk-on-main.sh`), `main` HEAD is commit **X** with `SDKVersion.swift` reading the released version, and commit **Y** was never created. Re-running `release.sh` won't recover — its pre-flight requires `SDKVersion.swift` to read `"Dev"` and will refuse to proceed.

Finish the release by running the remaining steps manually:

```bash
VERSION=<the version that was being released>

# If the GitHub release wasn't created (check the Releases page):
gh release create "$VERSION" --notes-file notes.md --title "$VERSION"

# Idempotent via `pod trunk info` — safe regardless of how far the script got:
bash scripts/publish-pods.sh "$VERSION"

# Creates commit Y and restores SDKVersion to "Dev":
bash scripts/restore-dev-sdk-on-main.sh "$VERSION"
```

`notes.md` is left in place when the script aborts (the success-path `rm` doesn't fire), so it's available for the `gh release create` call. Verify with `git log -2 --oneline` (Y on top of X) and `pod trunk info YouVersionPlatformCore` (latest matches `$VERSION`).

### Need an emergency release without the workflow

The pieces of `scripts/release.sh` can be run by hand:

```bash
VERSION=5.2.3

# Compute and inspect what would happen
node scripts/preview-release.mjs --base "$(git describe --tags --abbrev=0)" --head HEAD
node scripts/generate-release-notes.mjs --base "$(git describe --tags --abbrev=0)" --head HEAD --version "$VERSION" > notes.md

# Update files
bash scripts/update-pod-versions.sh "$VERSION"
bash scripts/stamp-sdk-version.sh "$VERSION"
# manually prepend notes.md to CHANGELOG.md

# Commit X, tag, push
git add CHANGELOG.md Sources/YouVersionPlatformCore/SDKVersion.swift *.podspec
git commit -m "chore(release): $VERSION [skip ci]" -m "$(cat notes.md)"
git tag "$VERSION"
git push origin main "$VERSION"

# Publish
bash scripts/publish-pods.sh "$VERSION"

# Restore Dev
bash scripts/restore-dev-sdk-on-main.sh "$VERSION"
```
