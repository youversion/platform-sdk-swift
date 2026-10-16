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

  > **PRs that introduce a breaking change require an explicit human signoff before merge.** When any commit on the PR carries a `BREAKING CHANGE:` footer or a `!` after the type/scope, the `major-release-signoff` status check blocks merging until a _different_ write-access collaborator (not the PR author) posts a single comment containing the verbatim affirmation phrase from the bot's blocking comment, the precise next version (e.g. `v6.0.0`), the full commit hash being approved, and a 🚀. See [RELEASING.md → Major Release Signoff](./RELEASING.md#major-release-signoff) for the exact comment format.

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
- Keep changes scoped to the requested module. Do not modify UI or downstream consumers unless required.
- Prefer production APIs that are natural for SDK users. Do not expose dependency-injection hooks solely for testing when an internal overload or test harness can provide control.
- Make types reflect real production guarantees. Do not preserve optional or fallback paths that can occur only in mocks.
- Do not use a local name that shadows a method.
- Prefer `if let` when it is clearer than optional `.map`.
- Use descriptive Boolean names such as `hasResource`.
- Do not add a helper for a single obvious one-line operation.
- Apply DRY when it centralizes a real rule or a repeated magic value. Leave a short, obvious expression local.
- Avoid adding initializer or factory-method variants to public views for optional configuration. Use custom view modifiers instead, following the `BibleReaderView(reference: ...).chapterHeader { ... }` pattern. Preserve established public initializers and factory methods for API compatibility.
- Never introduce an enum in the SDK's public API. Adding cases can break source compatibility for consumers with exhaustive switches. Follow the `VerseSelectionStyle` pattern instead: a public struct with named static presets. Keep any enum used to represent those presets internal or private. Preserve existing public enums; this rule applies to new API design.

See [.swiftlint.yml](./.swiftlint.yml) for detailed style rules.

### Git Workflow

**Important: Never push directly to `main`. Always use feature or task branches and pull requests.**

1. Create a branch named `<JIRA-TICKET>-<kebab-description>`, for example `YPE-5959-trim-agents-md-move-skills`. The ticket prefix comes first. There is no initials prefix and no `feature/` prefix. Every change needs a ticket, including doc-only edits.
2. Make your changes and commit using conventional commit format
3. Open a pull request. The pull request title matches the first line of the commit message. A task branch targets its feature branch. Other branches target `main`.
4. Ensure CI passes before requesting review

Feature branches cover a large task or several sub-tickets.

1. Create the feature branch from `main` using the parent epic's ticket, `<EPIC-TICKET>-<kebab-description>`.
2. Create task branches off the feature branch using each sub-ticket, `<TASK-TICKET>-<kebab-description>`.
3. Open pull requests from task branches targeting the feature branch.
4. Open a final pull request from the feature branch to `main` when the feature is complete.

To update a feature branch with changes from `main`, merge `main` into the feature branch first. Then merge the updated feature branch into the task branch. Never merge `main` directly into a task branch.

### Running Tests

```bash
# Run tests via Xcode
# Select the YouVersionPlatformPackageTests scheme and press Cmd+U

# Or via command line
swift test
```

### Linux

`YouVersionPlatformCore` tests must build and pass on Linux, where SwiftUI is unavailable.

In a Linux container, run SwiftLint with SourceKit configured:

```bash
LINUX_SOURCEKIT_LIB_PATH=/root/.local/share/swiftly/toolchains/6.1.3/usr/lib swiftlint --strict
```

If SwiftLint is not installed, get it from https://github.com/realm/SwiftLint/releases/latest/download/swiftlint_linux_amd64.zip or similar.

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

Keep the tracked placeholder `<#Your App Key#>` in `Examples/SampleApp/SampleApp.swift`. Leave a real key as an unstaged local change. Do not commit a real app key.

#### Device builds on BrowserStack

When an approved collaborator on `platform_swift_sdk_automation` opens a PR
from a branch in this repository, **BrowserStack App Live PR Build** dispatches
the existing automation build for the PR's exact head commit. New commits do
not rebuild automatically. To upload the current PR head again, an approved
collaborator comments exactly `/app-live` on the open PR. On this explicit
rebuild path, the commenter authorizes the current same-repository PR head; the
PR author does not also need access to the automation repository. The
automation repository builds and signs the SampleApp `.ipa`, uploads it to
BrowserStack App Live, and returns the `bs://...` app id in the SDK workflow
summary.
After a successful upload, `github-actions[bot]` creates or updates one PR
comment with the latest build details and the `/app-live` instruction.

Builds are numbered per PR: the key is the branch's ticket key plus the PR
number, incrementing for each upload, for example `swift-YPE-3011-pr227-1`
and `swift-YPE-3011-pr227-2`. A sanitized 10-character branch label plus the
PR number is used when the branch has no ticket key, for example
`feature/rework-reader` becomes `swift-rework-rea-pr226-1`. The exact source
SHA is recorded separately in the workflow summary.

This initial bridge produces an App Live build only. It does not run the Hinqa
corpus or upload to App Automate.

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](./LICENSE).
