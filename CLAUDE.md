# CLAUDE.md

This file provides guidance to AI agents when working with code in this repository.

## Essential Commands

### Code Quality
```bash
# Lint Swift code
swiftlint

# Check for unused code
periphery scan
```

### Dependencies
- **Swift Package Manager**: Primary dependency manager

## Development Notes

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
- Use GitHub to create pull requests (PRs).
- PR titles should always be the same as the first line of the commit message.
- When creating PRs, try to use the git config user email as the assignee.
- Prefer idiomatic, industry standard Swift style. Follow https://www.swift.org/documentation/api-design-guidelines/.
- Don't make whitespace-only changes.
- Read the swiftlint config file at @.swiftlint.yml for hints on preferred coding style.
- Prefer async-await to completion block-based API design.
- Async functions with return values should have names that are noun phrases describing the return value rather than verb phrases and should never begin with "get", "load", or "request".
- Don't add inline comments inside functions, but don't delete existing inline comments.
- Do add DocC comments to new, non-private functions, but not on SwiftUI initializers and body.
- Make access controls on properties and functions as strict as they can be (private, fileprivate, private(set), etc).
- Prefer to make entity properties immutable (let over var).
- Avoid abbreviations; prefer clarity over brevity.
- For Booleans, ensure that they start with a helping verb like "is", "should". "shows" and "showing" are also acceptable prefixes.
- Non-boolean entities should end with a word that indicates their data type (ex. "shadowColor" rather than "colorShadow" for a Color).
- Do not prepend "self." when it is unnecessary.
- Properties should be listed before all functions.
- Classes should be marked final if they have no subclasses.
- Prefer structs over classes.
- Don't leave unused code.
- Do not leave commented out code in place.
- Avoid abbreviations.
- Class, struct, enum entity names should always be in PascalCase.
- Property and function names should always be in camelCase.

## Localization

### SPM Resource Bundle Localization Workaround
When adding new localizations to the SDK, the Sample App requires dummy localization files to ensure iOS recognizes the supported languages:

1. Add translations to `Sources/YouVersionPlatformReader/Resources/Localizable.xcstrings`
2. Create a corresponding `.lproj` directory in `Examples/SampleApp/` (e.g., `de.lproj/`, `fr.lproj/`)
3. Add a dummy `Localizable.strings` file to each directory with content: `/* Dummy file to ensure [Language] localization is recognized */`
4. Add the language code to `knownRegions` in `Examples/SampleApp.xcodeproj/project.pbxproj`
5. Add the language code to `INFOPLIST_KEY_CFBundleLocalizations` in both Debug and Release build configurations

**Why this is necessary:** iOS requires apps to declare supported localizations via `CFBundleLocalizations` in Info.plist. Xcode only auto-generates this entry when the app target itself contains localized resources. Since all SDK localizations live in the SPM resource bundle, the dummy files force Xcode to recognize and declare the languages in the generated Info.plist, enabling proper language matching.