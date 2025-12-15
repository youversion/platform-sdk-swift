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

- Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages
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
