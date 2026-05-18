# Release Process

This project uses [semantic-release](https://semantic-release.gitbook.io/) for automated versioning and package publishing.

## Overview

Releases use [semantic-release](https://semantic-release.gitbook.io/) to compute the next version from [Conventional Commits](https://www.conventionalcommits.org/) since the last tag, but the release itself is **triggered manually**, not automatically on every push to `main`. A human (or scheduled job) decides when to cut a release; merging a PR by itself never publishes.

## How It Works

1. **Develop on a branch with conventional commit subjects** → the `Commit Lint` workflow validates each PR and previews the version that *would* be cut today.
2. **Merge PRs to `main`** → nothing publishes. `main` just accumulates work.
3. **When ready to release, trigger the Release workflow manually** → Actions tab → `Release` → "Run workflow" (or `gh workflow run release.yml`).
4. **Semantic-release analyzes commits since the last tag** → determines version bump (major/minor/patch).
5. **Version bump and changelog** → updates all 4 podspec files, stamps `SDKVersion.swift`, writes a `CHANGELOG.md` entry.
6. **Git tag and GitHub release** → creates the version tag (e.g., `5.3.0`) and a GitHub release.
7. **Publish to CocoaPods** → publishes all pods in dependency order.
8. **Restore `SDKVersion.swift` to `"Dev"`** → a follow-up commit returns the on-main constant to `"Dev"` so PR builds don't report a stale released version. The tag stays at the stamped commit (see [AGENTS.md → Release Process](./AGENTS.md#release-process) for the X/Y topology).

### Why manual

Auto-publishing on every push to `main` makes the publish surface too easy to trip — any commit message body or release-process change that an analyzer reads as a major bump goes straight to consumers. Manual trigger gives a deliberate review point between merge and publish, and keeps the per-PR version preview as the early warning.

## Commit Message Format

Use this format for all commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types (determines version bump)

- **feat**: A new feature (→ **MINOR** version bump, e.g., 1.0.0 → 1.1.0)
- **fix**: A bug fix (→ **PATCH** version bump, e.g., 1.0.0 → 1.0.1)
- **BREAKING CHANGE**: Breaking API change (→ **MAJOR** version bump, e.g., 1.0.0 → 2.0.0)

### Other types (no version bump)

- **docs**: Documentation changes
- **style**: Code formatting
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Test changes
- **build**: Build system changes
- **ci**: CI/CD changes
- **chore**: Maintenance tasks

### Examples

```bash
# Patch release (1.0.0 → 1.0.1)
git commit -m "fix: resolve crash on iPad when opening reader"

# Minor release (1.0.0 → 1.1.0)
git commit -m "feat: add dark mode support to reader"

# Major release (1.0.0 → 2.0.0)
git commit -m "feat: redesign Bible reader API

BREAKING CHANGE: BibleReader.open() now returns async Result<Void, Error>"

# With scope
git commit -m "fix(reader): correct verse highlighting behavior"
```

## Required GitHub Configuration

### GitHub Secrets

The following secrets must be configured in your GitHub repository:

#### 1. DEPLOY_KEY

An SSH private key used to bypass branch protection rules and push release commits/tags to `main`:

1. Generate an SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-semantic-release" -f deploy_key -N ""
   ```

2. Add the **public key** (`deploy_key.pub`) as a Deploy Key:
   - Go to `https://github.com/youversion/platform-sdk-swift/settings/keys`
   - Click "Add deploy key"
   - Title: `semantic-release` (or your preferred name)
   - Paste contents of `deploy_key.pub`
   - **Check "Allow write access"** ✓

3. Add the **private key** (`deploy_key`) as a repository secret:
   - Go to `https://github.com/youversion/platform-sdk-swift/settings/secrets/actions`
   - Click "New repository secret"
   - Name: `DEPLOY_KEY`
   - Value: Paste entire contents of `deploy_key` file

> **Important:** The secret name `DEPLOY_KEY` must match the reference in `.github/workflows/release.yml`. If you change the secret name, update the workflow file accordingly.

#### 2. COCOAPODS_TRUNK_TOKEN

Your CocoaPods trunk session token:

```bash
# Get your token from ~/.netrc after registering
cat ~/.netrc | grep cocoapods.org
```

Or get it from CocoaPods trunk:

```bash
pod trunk me
```

Add the token to repository secrets as `COCOAPODS_TRUNK_TOKEN`.

### Branch Protection Configuration

The Deploy Key bypasses the `main` branch protection ruleset that requires pull requests. To configure:

1. Go to `https://github.com/youversion/platform-sdk-swift/settings/rules`
2. Edit the ruleset for `main` branch
3. Under "Bypass list", ensure "Deploy keys" is enabled for bypass

This allows semantic-release to push release commits and tags directly to `main` during the automated release process.

## Testing Release Steps Locally

### Test commitlint

Conventional Commits are enforced in CI by `.github/workflows/commit-lint.yml`. There is no local Git hook — Xcode commits and Windows contributors bypass hooks too unreliably for that to be worth maintaining. To check your branch's commits locally before pushing:

```bash
# Lint every commit on your branch that isn't on main
npx commitlint --from=origin/main --to=HEAD --verbose

# Or, equivalently:
npm run commitlint

# Pipe a single message to test rule changes
echo "feat: add new feature" | npx commitlint
echo "invalid message" | npx commitlint   # should fail
```

### Test semantic-release (dry-run)

```bash
# See what version would be released
npx semantic-release --dry-run
```

### Test version update script

```bash
# Test updating to version 1.2.3 (won't actually publish)
bash scripts/update-pod-versions.sh 1.2.3
```

## Version Synchronization

All 4 podspecs are kept in sync:

- `YouVersionPlatformCore.podspec`
- `YouVersionPlatformUI.podspec` (depends on Core)
- `YouVersionPlatformReader.podspec` (depends on UI)
- `YouVersionPlatform.podspec` (umbrella, depends on all)

The `update-pod-versions.sh` script ensures:
- All podspecs get the same version number
- Inter-pod dependencies reference the correct version

## Publishing Order

Pods are published in dependency order:

1. **YouVersionPlatformCore** (no dependencies)
2. **YouVersionPlatformUI** (depends on Core)
3. **YouVersionPlatformReader** (depends on UI)
4. **YouVersionPlatform** (umbrella, depends on all)

## Manual Release (Emergency)

If you need to release manually:

```bash
# 1. Update versions
bash scripts/update-pod-versions.sh 1.2.3

# 2. Update CHANGELOG.md manually

# 3. Commit changes
git add .
git commit -m "chore(release): 1.2.3 [skip ci]"

# 4. Create tag
git tag 1.2.3

# 5. Push
git push origin main --tags

# 6. Publish to CocoaPods
bash scripts/publish-pods.sh 1.2.3

# 7. Create GitHub release manually
```

## Troubleshooting

### Release didn't trigger

- Verify you merged to `main` branch
- Check that commits follow Conventional Commits format
- Look at GitHub Actions logs for errors

### CocoaPods publish failed

- Verify `COCOAPODS_TRUNK_TOKEN` secret is set correctly
- Check that podspec files are valid: `pod spec lint *.podspec`
- Ensure you have permission to publish these pods

### Commitlint blocking commits

- Make sure your commit message follows the format: `type(scope): subject`
- Valid types: feat, fix, docs, style, refactor, perf, test, build, ci, chore
- Bypass temporarily (not recommended): `git commit --no-verify`

## Swift Package Manager

SPM uses git tags for versioning. When semantic-release creates a tag like `1.0.0`, SPM users can reference it in their `Package.swift`:

```swift
.package(url: "https://github.com/YouVersion/platform-sdk-swift.git", from: "1.0.0")
```

## Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [semantic-release Documentation](https://semantic-release.gitbook.io/)
- [Commitlint Rules](https://commitlint.js.org/#/reference-rules)
