# Release Process

This project uses [semantic-release](https://semantic-release.gitbook.io/) for automated versioning and package publishing.

## Overview

Releases are fully automated based on commit messages following the [Conventional Commits](https://www.conventionalcommits.org/) specification.

## How It Works

1. **Commit with conventional format** → Commitlint validates your message
2. **Merge to `main`** → GitHub Actions triggers semantic-release
3. **Semantic-release analyzes commits** → Determines version bump (major/minor/patch)
4. **Version bump and changelog** → Updates all 4 podspec files and CHANGELOG.md
5. **Git tag and GitHub release** → Creates version tag (e.g., `1.0.0`) and GitHub release
6. **Publish to CocoaPods** → Publishes all pods in dependency order

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

## Required GitHub Secrets

The following secrets must be configured in your GitHub repository:

### 1. GH_TOKEN

A Personal Access Token with `repo` permissions:

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with `repo` scope
3. Add to repository secrets as `GH_TOKEN`

### 2. COCOAPODS_TRUNK_TOKEN

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

## Testing Release Steps Locally

### Test commitlint

```bash
# Valid commit message
echo "feat: add new feature" | npx commitlint

# Invalid commit message (should fail)
echo "invalid message" | npx commitlint
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
