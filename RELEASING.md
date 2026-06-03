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

## Major Release Signoff

PRs that **introduce a breaking change** are gated by a required PR status check named `major-release-signoff`. The check runs on every PR via `.github/workflows/major-release-signoff.yml` and is a no-op for any PR that doesn't introduce a breaking change (i.e. anything the analyzer scores as `patch`, `minor`, or no bump).

A "breaking change" is detected the same way `@semantic-release/commit-analyzer` detects it — either a `BREAKING CHANGE:` body/footer token on any commit, or a `!` after the conventional-commit type (`feat!:`, `fix!:`, etc.). When that's present, the analyzer scores the PR as a major bump, and this check posts a blocking comment and stays in a `failure` state until any repo collaborator with `write`, `maintain`, or `admin` permission (and who is **not** the PR author) posts a single comment containing **all three (3) of the following:**

1. The verbatim affirmation phrase:

   > I confirm that this is an intentional breaking change, and I have read the release procedures. I understand and have documented its impact upon release.

2. The precise next version string (e.g. `v6.0.0` or `6.0.0`), and
3. A 🚀 (`:rocket:`) emoji.

A copy-paste-ready example (assuming the next version is `6.0.0`):

```
I confirm that this is an intentional breaking change, and I have read the release procedures. I understand and have documented its impact upon release.

v6.0.0 🚀
```

The matcher normalizes whitespace and strips Markdown blockquote markers (`>`), so using GitHub's "Quote reply" button on the bot's blocking comment also satisfies item (1) as long as the version and 🚀 are added in the same reply. The PR author is excluded — signoff has to come from a *different* write-access collaborator, so the gate guarantees a second pair of eyes.

The check re-runs automatically when a qualifying comment is posted or edited; once it sees a comment from a write-access collaborator containing both tokens, it flips to `success` and merging is unblocked. The approver's comment lives in PR history as the audit record — no extra log is required.

Permission is verified via `GET /repos/{owner}/{repo}/collaborators/{username}/permission` against the workflow-default `GITHUB_TOKEN`, so signoff authorization piggybacks on the same access list GitHub already uses for merge permissions — no separate allowlist file or org-scoped token to keep in sync.

If the PR doesn't actually contain a breaking change (e.g. the trigger is prose accidentally matching the `BREAKING CHANGE` token), the fix is in the commit messages, not the signoff: reword the offending commit subject/body so the analyzer no longer detects a breaking change (see the `Commit Lint` PR comment for which commit triggered it), force-push, and the gate will go green on its own.

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
4. Under "Require status checks to pass", add `major-release-signoff` to the required checks list so the gate actually blocks merges on major PRs (without this the workflow runs but the failure won't block the merge button).

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

For failure-by-failure recovery (trunk-API timeout, partial pod publish, post-push abort, diverged Dev-restore, rogue tag, expired trunk session, rejected SSH key) see [RELEASE-RUNBOOK.md](./RELEASE-RUNBOOK.md). The short version: **for almost every partial failure, re-dispatch `release.yml` with the same version**. `release.sh` detects when the tag already exists on origin and enters resume mode, replaying only the steps that didn't complete.

### The Commit Lint preview shows a major bump on a "patch" PR

`conventional-commits-parser` treats `BREAKING CHANGE` at the start of any commit body line as a breaking-change footer, regardless of surrounding markdown or quotes. The most common cause: a long commit body wraps and a paragraph happens to start with that token. Reword the offending line on your branch.

The analyzer log in the PR comment's `<details>` block shows which commit triggered the classification.

### The release dispatch is rejected with "is not strictly greater than current tag"

`release.sh` refuses to ship a version less than or equal to the latest tag — except when you're dispatching the **same** version that's already tagged on origin, which is the resume gesture and is allowed. If you typed the wrong version, dispatch with a corrected one.

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
