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
- Use GitHub to create pull requests (PRs).
- PR titles should always be the same as the first line of the commit message.
- Prefer idiomatic, industry standard Swift style. Follow https://www.swift.org/documentation/api-design-guidelines/.
- Don't make whitespace-only changes.
- Prefer async-await to completion block-based API design.
- Async functions with return values should have names that are noun phrases describing the return value rather than verb phrases and should never begin with "get", "load", "fetch", or "request".
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
- Public-facing types should generally include "YouVersion" in their name (e.g. `YouVersionBigButtonStyle`, `SignInWithYouVersionView`) to disambiguate from client-local types.
- Class, struct, enum entity names should always be in PascalCase.
- Property and function names should always be in camelCase.
- Prefer Swift Concurrency over Combine.
- Prefer `@Observable` to `ObservableObject`.
- ALWAYS mark ViewModel types as `@MainActor`.
- NEVER use locks (NSLock, etc.); prefer actors for isolation.
- For computed values with no arguments, prefer `var` over `func`.
- Don't specify `internal` — it's the default.
- No author attribution comment blocks (`// Created by`).
- Sort imports alphabetically.
- `else`/`catch` on the same line as the closing brace (`} else {`, `} catch {`).
- No blank lines at the top of `var`/`func`/`init` blocks.
- Always have one blank line between functions.
- Let the compiler infer types when possible.
- Use `""` over `String()` for empty strings.
- Use `private(set)` not `private (set)`.
- Use `private static` not `static private`.
- Don't use a comma between logical expressions when `&&` will suffice.
- Don't override methods or initializers only to call `super`.
- Do not add a `deinit` solely to remove `NotificationCenter` observers — it's unnecessary.
- When using `guard`, the `return`/`continue` belongs on a new line.
- Don't use `guard` in an overridden method to return early.
- Use existing localized strings if possible; prompt the user before adding new strings.
- Use Swift Testing for unit tests, not XCTest.
- NEVER create objects starting with `.init(...)`.
- Code MUST support iOS 17 but can branch using `if #available(iOS ##.#, *)` checks.
- Stored properties should be declared before all initializers.
- Derived properties and functions should be declared after all initializers.
- Use `Notification.Name("name")` not `Notification.Name(rawValue:)`, and `Notification.Name` not `NSNotification.Name`.
- Use local functions instead of inline closure blocks (`let x: () -> T = { ... }`).
- Don't unwrap optional closures with `if let` — use `closure?()`.
- Don't leave commented-out code in place.

### SwiftUI-Specific Rules

- Mark `@State` properties `private`.
- Do not use the suffix "Widget" for SwiftUI view names, as it conflicts with iOS home screen widgets (WidgetKit); use a more descriptive name instead.
- Use Dynamic Type text styles (`.body`, `.callout`, `.footnote`, etc.) instead of `.font(.system(size:))` so fonts adapt to the user's preferred text size.
- When using `Font.custom`, always include the `relativeTo:` parameter (e.g., `Font.custom("MyFont", size: 16, relativeTo: .callout)`) so custom fonts scale with Dynamic Type.

## Localization

### SPM Resource Bundle Localization Workaround
When adding new localizations to the SDK, the Sample App requires dummy localization files to ensure iOS recognizes the supported languages:

1. Add translations to `Sources/YouVersionPlatformReader/Resources/Localizable.xcstrings`
2. Create a corresponding `.lproj` directory in `Examples/SampleApp/` (e.g., `de.lproj/`, `fr.lproj/`)
3. Add a dummy `Localizable.strings` file to each directory with content: `/* Dummy file to ensure [Language] localization is recognized */`
4. Add the language code to `knownRegions` in `Examples/SampleApp.xcodeproj/project.pbxproj`
5. Add the language code to `INFOPLIST_KEY_CFBundleLocalizations` in both Debug and Release build configurations

**Why this is necessary:** iOS requires apps to declare supported localizations via `CFBundleLocalizations` in Info.plist. Xcode only auto-generates this entry when the app target itself contains localized resources. Since all SDK localizations live in the SPM resource bundle, the dummy files force Xcode to recognize and declare the languages in the generated Info.plist, enabling proper language matching.
