# Contributing to YouVersion Platform Swift SDK

Thank you for your interest in contributing to the YouVersion Platform Swift SDK!

## Development Guidelines

### Prerequisites

- Xcode 16+ with Swift 6.0
- iOS 17+ / macOS 15+ deployment targets
- [SwiftLint](https://github.com/realm/SwiftLint) for code linting
- [Periphery](https://github.com/peripheryapp/periphery) for detecting unused code

### Project Structure

This SDK is organized as a Swift Package with multiple targets:

- `YouVersionPlatformCore` - Core API and data types (cross-platform)
- `YouVersionPlatformUI` - SwiftUI components for displaying Bible content
- `YouVersionPlatformReader` - Full Bible reader experience
- `YouVersionPlatform` - Umbrella target that re-exports all modules

### Development Workflow

1. Clone the repository
2. Open `Package.swift` in Xcode
3. Make your changes
4. Run `swiftlint` to check code style
5. Run `periphery scan` to detect unused code
6. Run tests with `Cmd+U` in Xcode
7. Submit your PR

### Code Style

This project follows idiomatic Swift conventions as outlined in [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). Key points:

- Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages — they drive the version-preview analyzer and the auto-generated CHANGELOG. Validated in CI by the `Commit Lint` workflow; check locally with `npm run commitlint` (or `npx commitlint --from=origin/main --to=HEAD --verbose`).

  > **⚠️ Important: every commit subject on `main` is scanned by the analyzer to suggest the next version when a release is cut.**
  >
  > This repo squash-merges PRs. The **squash commit subject becomes a single commit on `main`** — its `<type>` is what the analyzer reads, not the individual commits on your branch. GitHub seeds the squash subject from the PR title by default, so **make sure your PR title is itself a valid Conventional Commit** (e.g. `feat(reader): add highlight color picker`). If the squash subject is `chore:` it contributes no release signal even if every commit on your branch was a `feat`.
  >
  > Releases are cut on demand with an explicit version input — see [RELEASING.md](./RELEASING.md). The analyzer walks every commit since the last release tag and picks the **highest** bump it finds across that window — one `feat` among ten `chore`s suggests a minor release; one `BREAKING CHANGE` footer (or `!` shorthand) anywhere suggests a major. The CI `Commit Lint` workflow on each PR shows that preview, and the Release workflow logs it side-by-side with the human's chosen version for audit. The human's input is what actually ships; the analyzer's value is informational.

  **Format:** `<type>(<optional scope>): <subject>`

  **Allowed types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

  **Version-bump behavior:**
  - `feat:` → **minor** bump (e.g. `5.2.2` → `5.3.0`)
  - `fix:` and `perf:` → **patch** bump (e.g. `5.2.2` → `5.2.3`)
  - `docs`, `style`, `refactor`, `test`, `build`, `ci`, `chore`, `revert` → **no release**
  - Any commit with `!` after the type/scope, **or** a `BREAKING CHANGE:` footer → **major** bump (e.g. `5.2.2` → `6.0.0`)

  **Examples (annotated with the bump each one would trigger):**

  ```text
  feat(reader): add highlight color picker to BibleReaderView
  # → MINOR: 5.2.2 → 5.3.0

  fix(core): normalize bookUSFM case in overlaps/contains
  # → PATCH: 5.2.2 → 5.2.3

  perf(reader): cache verse layout to avoid recomputation on scroll
  # → PATCH: 5.2.2 → 5.2.3

  docs: clarify SDK installation steps in README
  # → NO RELEASE

  refactor(ui): extract VerseRow into its own SwiftUI view
  # → NO RELEASE

  chore(deps): bump SwiftLint to 0.55.1
  # → NO RELEASE

  feat(api)!: rename PlatformClient.fetch(_:) to PlatformClient.load(_:)

  BREAKING CHANGE: `fetch(_:)` has been removed. Migrate to `load(_:)`,
  which throws instead of returning an optional.
  # → MAJOR: 5.2.2 → 6.0.0  (the `!` is enough; the footer adds CHANGELOG detail)
  ```

  Keep the subject in the imperative mood ("add", "fix", "rename" — not "added"/"fixes"). Use a `scope` (e.g. `reader`, `core`, `ui`, `api`) when the change is localized; omit it when the change is repo-wide.
- Run `swiftlint` before submitting PRs
- Prefer `async`/`await` over completion handlers
- Use protocol-oriented programming patterns
- Make access controls as strict as possible (`private`, `fileprivate`, etc.)
- Prefer structs over classes
- Avoid abbreviations; prefer clarity over brevity

See [CLAUDE.md](./CLAUDE.md) and [.swiftlint.yml](./.swiftlint.yml) for detailed style rules.

### Git Workflow

**Important: Never push directly to `main`. Always use feature/task branches and pull requests.**

1. Create a branch from `main` using the pattern: `initials/ticket-number` or `initials/description`
2. Make your changes and commit using conventional commit format
3. Create a PR targeting `main`
4. Ensure CI passes before requesting review

### Running Tests

```bash
# Run tests via Xcode
# Select the YouVersionPlatformPackageTests scheme and press Cmd+U

# Or via command line
swift test
```

### Code Coverage

Code coverage is automatically tracked and reported in CI:

- **Pull Requests**: A coverage report is posted as a comment on each PR, showing line coverage for changed files and the overall project.
- **Main Branch**: After merging to `main`, the coverage badge in the README is automatically updated.

To generate a coverage report locally:

```bash
# Run tests with coverage enabled
xcodebuild \
  -scheme YouVersionPlatform \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath DerivedData \
  -enableCodeCoverage YES \
  test

# View coverage in Xcode
# Open the Report Navigator (Cmd+9) and select the test run to see coverage details
```

### Sample App

The `Examples/SampleApp` directory contains a sample iOS app demonstrating SDK usage. To run it:

1. Open the project in Xcode
2. Select the `SampleApp` scheme
3. Build and run on simulator or device

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](./LICENSE).
