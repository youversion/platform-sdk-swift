# Agent instructions for `platform-sdk-swift`

Public Swift package at https://github.com/youversion/platform-sdk-swift. Third-party apps use YouVersion Platform APIs, Bible text helpers, and SwiftUI views, up to a drop-in Bible reader.
Consumer docs: README.md and https://developers.youversion.com/sdks/swift.

## Modules

- `YouVersionPlatformCore`: API clients and shared types. No SwiftUI.
- `YouVersionPlatformUI`: SwiftUI views for Bible text.
- `YouVersionPlatformReader`: drop-in Bible reader.
- Core tests must run where SwiftUI is unavailable. See CONTRIBUTING.md, Linux.

## Read these, do not copy them

- Branches, commits, lint, tests, Linux, the Sample App app key, and review preferences: CONTRIBUTING.md
- Versions and publishing: RELEASING.md
- Failed release recovery: RELEASE-RUNBOOK.md
- CI: the `.github/workflows` directory
- User-facing strings: open a pull request in platform-localization that edits `sources/common/en.json`. Do not edit `Localizable.xcstrings` here. Details: docs/localization-guardrails.md

## Public API

- `.api-baseline/` guards source-breaking changes. Verify with `scripts/check-api-stability.sh check`. The script header documents regenerating baselines for an intentional major-version break.
- New public symbols need acknowledgment from a maintainer other than the author. See docs/api-additions-signoff.md.

## Skills

Load the relevant skill before writing or reviewing Swift in this repo.

- Project Swift conventions: `skills/audit-swift/SKILL.md`
- SwiftUI rules: `skills/audit-swift-ui/SKILL.md`
- Naming types, functions, and parameters: `skills/naming/SKILL.md`
