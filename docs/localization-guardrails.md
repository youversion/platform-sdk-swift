# Localization Guardrails

User-facing copy in the YouVersion Platform SDK (Swift) is owned by [platform-localization](https://github.com/youversion/platform-localization) and synced into this repository. SDK modules must not ship new hardcoded UI strings, and the string catalog must not be edited directly in feature PRs.

## String architecture

| Layer | File | Who edits |
|-------|------|-----------|
| Canonical catalog | `Sources/YouVersionPlatformUI/Resources/Localizable.xcstrings` | platform-localization sync workflow only |
| SDK access API | `String.localized(_:)` in `Sources/YouVersionPlatformUI/Utilities/LocalizationHelpers.swift` | SDK developers (API only) |

**Modules with UI strings:** `YouVersionPlatformUI`, `YouVersionPlatformReader`

**Out of scope:** `Tests/**`, `Examples/**` (demo app)

## How to add or change user-facing copy

1. Add or update keys in **platform-localization** under `sources/common/en.json` using the `swift.*` prefix (or shared unprefixed keys where appropriate).
2. Wait for the localization distribute workflow to open a sync PR in this repo on branch `chore/localization-sync-swift` (legacy dated branches `chore/localization-sync-swift-{YYYYMMDD}-{sha7}` are also accepted) authored by `app/platform-localization-pr-bot`.
3. After the sync PR merges, reference the key in SDK code with `String.localized("dotted.key")`.

Do **not** hand-edit `Localizable.xcstrings` in feature PRs.

### Example

```swift
Text(String.localized("generic.cancel"))
Button(String.localized("download.agreeButton")) { ... }
    .accessibilityLabel(String.localized("signIn.button.accessibility"))
```

## Enforcement

| Layer | Mechanism | Blocks merge? |
|-------|-----------|---------------|
| **CI** | `.github/workflows/localization.yml` — locale ownership | Yes |
| **CI** | `scripts/check-no-hardcoded-ui-strings.sh` | Yes |
| **CI** | `scripts/check-localization-keys.sh` | Yes |
| **SwiftLint** | `hardcoded_ui_string` custom rule (error) | Yes |
| **Greptile** | `greptile.json` advisory rules | No (advisory PR comments) |

### Local checks

```bash
# Block manual catalog edits (simulate a feature PR)
BASE_SHA=main HEAD_SHA=HEAD PR_AUTHOR=your-user HEAD_REF=feature/foo \
  bash .github/scripts/check-locale-ownership.sh

# Fail on hardcoded UI strings in UI + Reader modules
bash scripts/check-no-hardcoded-ui-strings.sh

# Fail when String.localized keys are missing an English value in the catalog
bash scripts/check-localization-keys.sh

swiftlint --strict
swift test
```

## Hardcoded string policy

The CI script and SwiftLint rule scan `Sources/YouVersionPlatformUI/**` and `Sources/YouVersionPlatformReader/**` for raw string literals passed to:

- `Text(...)`, `Button(...)`, `Label(...)`
- `.navigationTitle(...)`, `.navigationBarTitle(...)`
- `.accessibilityLabel(...)`, `.accessibilityHint(...)`
- `alert(...)`, `confirmationDialog(...)` title/message string literals

**Fix violations** by wiring `String.localized("existing.key")` or adding keys upstream in platform-localization and consuming them after sync.

### Exclusions (not flagged)

| Category | Examples | CI script | SwiftLint rule |
|----------|----------|-----------|----------------|
| Tests & examples | `Tests/**`, `Examples/**` | ✅ | ✅ |
| Single-character glyphs | Font-size `Text("A")` in font settings | ✅ | ✅ |
| Localized values | `Text(String.localized("generic.ok"))` | ✅ | ✅ |
| Verbatim text | `Text(verbatim: "Test")` | ✅ | ✅ |
| `#Preview` blocks | SwiftUI preview scaffolding | ✅ | ❌ |
| Comments | `// e.g. Text("example")` | ✅ | ❌ |
| Allowlisted exceptions | `config/i18n/hardcoded-string-allowlist.txt` | ✅ | ❌ |

The two gates are not identical: SwiftLint is a plain regex and does not read the
allowlist or skip `#Preview` blocks and comments. For text that is intentionally
unlocalized (preview scaffolding, glyphs longer than one character), prefer
`Text(verbatim: "...")`, which passes both gates and states the intent; a
`// swiftlint:disable:next hardcoded_ui_string` comment is the fallback for
APIs without a verbatim form.

Allowlist entries (CI script only) use `path`, `path:pattern`, or
`path:line:pattern`, where `path` is a substring of the repo-relative file path
and `pattern` is a substring of the code on the matched line.

Prefer fixing call sites over adding allowlist entries.

## Catalog ownership (locale sync PRs)

`Localizable.xcstrings` may only be modified by localization sync PRs when **both** are true:

- PR author is the platform-localization GitHub App — its login surfaces as `platform-localization-pr-bot[bot]` in the `pull_request` event (the `app/platform-localization-pr-bot` form used by some CLI/API contexts is also accepted)
- Head branch is `chore/localization-sync-swift` or matches legacy `chore/localization-sync-swift-*`

All other PRs that touch the catalog fail CI with a link to this document.

Sync PRs still run the hardcoded-string and key-existence checks.

## Greptile

Advisory localization rules live in `greptile.json`. Greptile supplements but does not replace CI merge gates.

Re-trigger review after config changes with `@greptileai review`.

## References

- String catalog: `Sources/YouVersionPlatformUI/Resources/Localizable.xcstrings`
- Hardcoded-string allowlist: `config/i18n/hardcoded-string-allowlist.txt`
- CI workflow: `.github/workflows/localization.yml`
- Upstream repo: [platform-localization](https://github.com/youversion/platform-localization)
