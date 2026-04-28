# Agent instructions for `platform-sdk-swift`

This is a public repo, living at https://github.com/youversion/platform-sdk-swift

It provides an SDK for developers to use the YouVersion Platform APIs easily on Swift platforms e.g. iOS and iPadOS.

The SDK includes API access helpers, convenience classes and methods for working with Bible text, and SwiftUI views to make displaying scripture easy.

## Documentation

In addition to the README.md in this repo, more official documentation is at https://developers.youversion.com/sdks/swift

## Structure

This repo contains the SPM package YouVersionPlatform, which consists of:
- YouVersionPlatformCore: the core classes and supporting helpers for making API calls
- YouVersionPlatformUI: the base SwiftUI views for e.g. displaying Bible text with BibleTextView
- YouVersionPlatformReader: a fully-featured, drop-in Bible reader called BibleReaderView, built to look and work like the YouVersion Bible App. Includes many UI components such as Bible version pickers, Book/Chapter picker, footnote display, etc.

Tests are in the top-level Tests dir. The tests of YouVersionPlatformCore must run on environments e.g. Linux which don't have SwiftUI available.

## Required local checks

- Always run `swift test` and SwiftLint on code changes before finalizing work.

## Public API Stability

Source-breaking changes to the SDK's public interface are blocked by a CI job
(`.github/workflows/api-stability.yml`) that diffs the PR's API surface against
committed baselines under `.api-baseline/`. Additive changes pass; renames,
removals, and signature changes fail until the baseline is intentionally
updated as part of a major version bump.

To verify locally:

```bash
scripts/check-api-stability.sh check
```

When a breaking change is intentional (typically as part of a major version
bump), update the baselines and commit them in the same PR:

```bash
scripts/check-api-stability.sh update
```

The baseline files are JSON dumps from `swift-api-digester` covering
`YouVersionPlatformCore`, `YouVersionPlatformUI`, and `YouVersionPlatformReader`.

## SwiftLint

In a Linux container, run SwiftLint with SourceKit configured:

```bash
LINUX_SOURCEKIT_LIB_PATH=/root/.local/share/swiftly/toolchains/6.1.3/usr/lib swiftlint --strict
```

(If SwiftLint is not installed, get it from https://github.com/realm/SwiftLint/releases/latest/download/swiftlint_linux_amd64.zip or similar.)

### Testing Strategy
- Unit tests for core functionality

### Code Style
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) for commit messages (enforced by commitlint)
- Protocol-oriented programming patterns
- Extensive use of extensions for code organization

## Common Workflows

### Git Branching Process
The project follows a structured git workflow with `main` as the primary branch.

**⚠️ IMPORTANT: Never push directly to main. Always use feature/task branches and pull requests.**

**Small Tasks (Non-Urgent):**
1. Create task branch from `main` using pattern: `initials/ticket-number` or `initials/ticket-number-description`
   - Examples: `dk/BA-1204`, `ew/BA-1204-plans-update`, `jm/plans-update`, `ae/BA-5678`
2. Complete work and create PR targeted back to `main`

**Feature Branches:**
Use for large tasks or risky changes (SDK updates, major API adoption):
1. Create feature branch from `main` with `feature/` prefix
   - Examples: `feature/offline-search`
2. Create task branches off the feature branch
3. Create PRs targeting the feature branch
4. Merge task branches into feature branch
5. Merge feature branch into `main` once approved

**Updating Feature Branches:**
- Merge `main` into feature branch first
- Then merge updated feature branch into task branch
- Never merge `main` directly into task branch

### Adding New Features
1. Identify the appropriate internal framework or create new module
2. Follow existing architectural patterns (MVC/MVVM)
3. Add unit tests for new functionality
4. Update localization if needed
5. Run `swiftlint` to ensure code style compliance

## Important Tips
- Never commit a real `appKey` to the remote. In `Examples/SampleApp/SampleApp.swift`, keep the tracked placeholder `<#Your App Key#>` and leave your real key as an unstaged local change.
- Use GitHub to create pull requests (PRs).
- PR titles should always be the same as the first line of the commit message.

## Code style references

When writing or reviewing code in this repo, load the relevant skill:

- **`audit-swift`** (`.claude/skills/audit-swift/SKILL.md`) — project Swift conventions: access control, async/await, code organization, idioms, formatting.
- **`audit-swift-ui`** (`.claude/skills/audit-swift-ui/SKILL.md`) — SwiftUI-specific rules: Dynamic Type, `@State` privacy, view naming.
- **`naming`** (`.claude/skills/naming/SKILL.md`) — naming Swift entities (types, protocols, functions, parameters, properties, cases).

## Localization

### SPM Resource Bundle Localization Workaround
When adding new localizations to the SDK, the Sample App requires dummy localization files to ensure iOS recognizes the supported languages:

1. Add translations to `Sources/YouVersionPlatformReader/Resources/Localizable.xcstrings`
2. Create a corresponding `.lproj` directory in `Examples/SampleApp/` (e.g., `de.lproj/`, `fr.lproj/`)
3. Add a dummy `Localizable.strings` file to each directory with content: `/* Dummy file to ensure [Language] localization is recognized */`
4. Add the language code to `knownRegions` in `Examples/SampleApp.xcodeproj/project.pbxproj`
5. Add the language code to `INFOPLIST_KEY_CFBundleLocalizations` in both Debug and Release build configurations

**Why this is necessary:** iOS requires apps to declare supported localizations via `CFBundleLocalizations` in Info.plist. Xcode only auto-generates this entry when the app target itself contains localized resources. Since all SDK localizations live in the SPM resource bundle, the dummy files force Xcode to recognize and declare the languages in the generated Info.plist, enabling proper language matching.
