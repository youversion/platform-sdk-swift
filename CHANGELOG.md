# Changelog

All notable changes to this project will be documented in this file.

## [6.0.0](https://github.com/youversion/platform-sdk-swift/compare/5.2.2...6.0.0) (2026-05-18)


### ⚠ BREAKING CHANGES

* footers.
  - Posts a sticky PR comment (via peter-evans/find-comment +
    create-or-update-comment) on both success and failure, with a prominent
    warning when a major bump is detected.
  - Treats a non-zero semantic-release dry-run as a warning only, so a release
    config glitch never blocks unrelated PRs.
- Add an `npm run commitlint` script for local pre-push validation.
- Update AGENTS.md, RELEASING.md, and CONTRIBUTING.md to describe the new
  CI-enforced flow and the local check.

Refs YPE-2398

Co-Authored-By: Craft Agent <agents-noreply@craft.do>

* fix(ci): pin commit-lint actions to SHAs, catch feat! breaking changes, drop edited trigger

Addresses three review comments on the commit-lint workflow:

- Pin peter-evans/find-comment and peter-evans/create-or-update-comment to
  full commit SHAs (v3.1.0 and v4.0.0 respectively). Floating major tags
  could be silently force-pushed to a malicious SHA, and this workflow has
  `pull-requests: write`.
- Detect major releases via semantic-release's own log line ("complete:
  major release" / "release type is major") instead of grepping for the
  literal "BREAKING CHANGE" string. The previous check missed the `feat!:`
  and `fix!:` shorthand, which produces a major bump without emitting the
  footer keyword. Banner now fires correctly for both forms.
- Drop the `edited` PR trigger. It re-ran the full workflow on every PR
  title/body edit despite the workflow only validating commit-range
  contents, not PR metadata. `synchronize` already re-runs on every new
  commit push, which is the only event that can change what we lint.

Refs YPE-2398

Co-Authored-By: Craft Agent <agents-noreply@craft.do>

* fix(ci): make semantic-release dry-run actually compute the next version, expand commit examples

- semantic-release was logging "configured to only run on main" and bailing
  on PR runs because HEAD is `refs/pull/N/merge`, which isn't in the
  `branches` allowlist. The previous `--branches` override was the wrong
  knob: that controls _which_ branch can release, not _which_ branch
  semantic-release thinks it's on. Now we point a local branch at the PR
  merge commit using the base ref name and let semantic-release run as if
  the PR had already merged, which is exactly the preview we want.
- Address review feedback on CONTRIBUTING.md: add a fuller Conventional
  Commits section with type list, version-bump table, six worked examples
  (feat / fix / docs / refactor / chore / breaking change with footer),
  and a note about imperative mood and scopes. Aimed at coding agents and
  humans who haven't internalized the spec.

Refs YPE-2398

Co-Authored-By: Craft Agent <agents-noreply@craft.do>

* fix(ci): strip GitHub Actions env vars so semantic-release dry-run detects the right branch

Previous fix moved git HEAD to a local branch named after the PR base ref,
but semantic-release never looked at git — it relies on env-ci, which
reads GITHUB_ACTIONS + GITHUB_REF + GITHUB_EVENT_NAME and reports the
branch as `refs/pull/N/merge` on PR events. That ref never matches the
configured `branches: ["main"]` allowlist, so the analyzer bails with
"triggered on the branch refs/pull/N/merge ... won't be published"
before computing a version. The --no-ci flag bypasses the CI auth check,
not the env-ci branch detection.

Wrap the semantic-release invocation in `env -u ...` to unset the
GitHub Actions env vars that signal "PR in CI". env-ci then falls back
to git-based detection and sees us on `main` (because of the local
checkout in the previous step), so the analyzer runs end-to-end and the
PR comment shows the real next version.

GITHUB_TOKEN is preserved so the @semantic-release/github plugin's
verifyConditions step still passes.

Refs YPE-2398

Co-Authored-By: Craft Agent <agents-noreply@craft.do>

* docs: annotate commit examples with version bumps and call out squash-merge behavior

Two pieces of contributor feedback on CONTRIBUTING.md:

- Each example now shows the bump it would trigger (MINOR / PATCH /
  NO RELEASE / MAJOR) with concrete before-and-after versions, so
  contributors and agents can see the consequence at a glance.
- Add an explicit callout that this repo squash-merges and that the
  squash commit subject — seeded from the PR title — is what
  semantic-release reads on `main`. Also state that the entire commit
  history back to the last tag is scanned and the highest bump wins.
  This prevents the "all my commits were `feat` but the PR was titled
  `chore: ...` and no release happened" trap.

Refs YPE-2398

Co-Authored-By: Craft Agent <agents-noreply@craft.do>

* refactor(ci): simplify semantic-release dry-run with --branches '**' --no-ci

Replace the env-var stripping + local-branch-rename dance with the
direct CLI override: `--branches '**' --no-ci`. `--branches '**'`
loosens the analyzer's branch allowlist for this invocation only (the
`.releaserc.json` config is untouched, so real releases are still
locked to `main`), and `--no-ci` bypasses the refuse-on-PR check.
Same dry-run output, ~10 fewer lines, no GITHUB_* env juggling.

Refs YPE-2398

Co-Authored-By: Craft Agent <agents-noreply@craft.do>

* fix(ci): scope semantic-release dry-run --branches to the PR head ref only

`--branches '**'` expanded against every branch in the repo (~13) and
tripped semantic-release's max-3-release-branches validation:
ERELEASEBRANCHES "The release branches are invalid". Limit the override
to a single entry — the PR head branch — which is what env-ci already
detects us on. That keeps the allowlist exactly one branch wide, well
under the limit, and aligned with the detected branch so the analyzer
runs end-to-end.

The file config in `.releaserc.json` is still untouched, so real
releases continue to ship only from `main`.

Refs YPE-2398

Co-Authored-By: Craft Agent <agents-noreply@craft.do>

* fix(ci): unset GITHUB_ACTIONS for semantic-release dry-run (canonical workaround)

### Continuous Integration

* replace Husky commit-msg hook with CI commit-lint + release preview ([#117](https://github.com/youversion/platform-sdk-swift/issues/117)) ([1d21411](https://github.com/youversion/platform-sdk-swift/commit/1d214119f6e4792d6c49607f4d37d425df1e20d4)), closes [#1886](https://github.com/youversion/platform-sdk-swift/issues/1886) [#1937](https://github.com/youversion/platform-sdk-swift/issues/1937)

## [5.2.2](https://github.com/youversion/platform-sdk-swift/compare/5.2.1...5.2.2) (2026-05-15)


### Bug Fixes

* BibleReaderViewModel created on every render ([#122](https://github.com/youversion/platform-sdk-swift/issues/122)) ([8dad856](https://github.com/youversion/platform-sdk-swift/commit/8dad8567eca81ef94d78ee1376a05903178fd76b))

## [5.2.1](https://github.com/youversion/platform-sdk-swift/compare/5.2.0...5.2.1) (2026-05-11)


### Bug Fixes

* normalize bookUSFM case in overlaps/contains and fix chapter-only USFM parsing ([52b9bf5](https://github.com/youversion/platform-sdk-swift/commit/52b9bf5b6b8bfe2b68ed888a5c4b6268eb7233bf))

## [5.2.0](https://github.com/youversion/platform-sdk-swift/compare/5.1.1...5.2.0) (2026-05-08)


### Features

* **reader:** limit versions by language and version id ([#101](https://github.com/youversion/platform-sdk-swift/issues/101)) ([979f5ac](https://github.com/youversion/platform-sdk-swift/commit/979f5ace1e4243bcf840b49f3e426154cd828ea0))

## [5.1.1](https://github.com/youversion/platform-sdk-swift/compare/5.1.0...5.1.1) (2026-05-08)


### Bug Fixes

* **ci:** make pod publish resumable after partial trunk failure ([#112](https://github.com/youversion/platform-sdk-swift/issues/112)) ([77c45d0](https://github.com/youversion/platform-sdk-swift/commit/77c45d0430aab952e35c5840c9c1413111e1b934))

## [5.1.0](https://github.com/youversion/platform-sdk-swift/compare/5.0.0...5.1.0) (2026-05-07)


### Features

* add x-yvp-sdk header reporting SDK version on configured requests ([#103](https://github.com/youversion/platform-sdk-swift/issues/103)) ([2cd621a](https://github.com/youversion/platform-sdk-swift/commit/2cd621a946e091daf832c583906860b812b73293))


### Bug Fixes

* **ci:** fix release script reset stale origin for YPE-2293  ([#105](https://github.com/youversion/platform-sdk-swift/issues/105)) ([1db2e3a](https://github.com/youversion/platform-sdk-swift/commit/1db2e3a76fdd81200c5b7f599a1b0bef4e109ee4)), closes [#1](https://github.com/youversion/platform-sdk-swift/issues/1)
* **ci:** keep release tag on main so semantic-release can find it on next run.  ([#110](https://github.com/youversion/platform-sdk-swift/issues/110)) ([da7b8be](https://github.com/youversion/platform-sdk-swift/commit/da7b8bebec1b72fe82e821e15bad8c87dd76bb8f))
* pluralize versionList.statisticsFormat in all locales ([db0eac4](https://github.com/youversion/platform-sdk-swift/commit/db0eac4e21302c637b525a1751070f8836fa8ec3))

## [5.1.0](https://github.com/youversion/platform-sdk-swift/compare/5.0.0...5.1.0) (2026-05-06)


### Features

* add x-yvp-sdk header reporting SDK version on configured requests ([#103](https://github.com/youversion/platform-sdk-swift/issues/103)) ([2cd621a](https://github.com/youversion/platform-sdk-swift/commit/2cd621a946e091daf832c583906860b812b73293))


### Bug Fixes

* **ci:** fix release script reset stale origin for YPE-2293  ([#105](https://github.com/youversion/platform-sdk-swift/issues/105)) ([1db2e3a](https://github.com/youversion/platform-sdk-swift/commit/1db2e3a76fdd81200c5b7f599a1b0bef4e109ee4)), closes [#1](https://github.com/youversion/platform-sdk-swift/issues/1)
* pluralize versionList.statisticsFormat in all locales ([db0eac4](https://github.com/youversion/platform-sdk-swift/commit/db0eac4e21302c637b525a1751070f8836fa8ec3))

## [5.1.0](https://github.com/youversion/platform-sdk-swift/compare/5.0.0...5.1.0) (2026-05-06)


### Features

* add x-yvp-sdk header reporting SDK version on configured requests ([#103](https://github.com/youversion/platform-sdk-swift/issues/103)) ([2cd621a](https://github.com/youversion/platform-sdk-swift/commit/2cd621a946e091daf832c583906860b812b73293))


### Bug Fixes

* **ci:** fix release script reset stale origin for YPE-2293  ([#105](https://github.com/youversion/platform-sdk-swift/issues/105)) ([1db2e3a](https://github.com/youversion/platform-sdk-swift/commit/1db2e3a76fdd81200c5b7f599a1b0bef4e109ee4)), closes [#1](https://github.com/youversion/platform-sdk-swift/issues/1)
* pluralize versionList.statisticsFormat in all locales ([db0eac4](https://github.com/youversion/platform-sdk-swift/commit/db0eac4e21302c637b525a1751070f8836fa8ec3))

## [5.1.0](https://github.com/youversion/platform-sdk-swift/compare/5.0.0...5.1.0) (2026-05-06)


### Features

* add x-yvp-sdk header reporting SDK version on configured requests ([#103](https://github.com/youversion/platform-sdk-swift/issues/103)) ([2cd621a](https://github.com/youversion/platform-sdk-swift/commit/2cd621a946e091daf832c583906860b812b73293))


### Bug Fixes

* **ci:** fix release script reset stale origin for YPE-2293  ([#105](https://github.com/youversion/platform-sdk-swift/issues/105)) ([1db2e3a](https://github.com/youversion/platform-sdk-swift/commit/1db2e3a76fdd81200c5b7f599a1b0bef4e109ee4)), closes [#1](https://github.com/youversion/platform-sdk-swift/issues/1)
* pluralize versionList.statisticsFormat in all locales ([db0eac4](https://github.com/youversion/platform-sdk-swift/commit/db0eac4e21302c637b525a1751070f8836fa8ec3))

## [5.1.0](https://github.com/youversion/platform-sdk-swift/compare/5.0.0...5.1.0) (2026-05-06)


### Features

* add x-yvp-sdk header reporting SDK version on configured requests ([#103](https://github.com/youversion/platform-sdk-swift/issues/103)) ([2cd621a](https://github.com/youversion/platform-sdk-swift/commit/2cd621a946e091daf832c583906860b812b73293))


### Bug Fixes

* pluralize versionList.statisticsFormat in all locales ([db0eac4](https://github.com/youversion/platform-sdk-swift/commit/db0eac4e21302c637b525a1751070f8836fa8ec3))

## [5.1.0](https://github.com/youversion/platform-sdk-swift/compare/5.0.0...5.1.0) (2026-05-06)


### Features

* add x-yvp-sdk header reporting SDK version on configured requests ([#103](https://github.com/youversion/platform-sdk-swift/issues/103)) ([2cd621a](https://github.com/youversion/platform-sdk-swift/commit/2cd621a946e091daf832c583906860b812b73293))


### Bug Fixes

* pluralize versionList.statisticsFormat in all locales ([db0eac4](https://github.com/youversion/platform-sdk-swift/commit/db0eac4e21302c637b525a1751070f8836fa8ec3))

## [4.10.0](https://github.com/youversion/platform-sdk-swift/compare/4.9.2...4.10.0) (2026-05-06)


### Features

* add x-yvp-sdk header reporting SDK version on configured requests ([#103](https://github.com/youversion/platform-sdk-swift/issues/103)) ([2cd621a](https://github.com/youversion/platform-sdk-swift/commit/2cd621a946e091daf832c583906860b812b73293))

## [5.0.0](https://github.com/youversion/platform-sdk-swift/compare/4.9.1...5.0.0) (2026-05-01)


### ⚠ BREAKING CHANGES

* BibleVersionAPIClient, BibleVersionCaching, and VersionClient have
  been removed from the public API. BibleVersionRepositoryProtocol now requires
  downloadedVersionIds. Callers that implemented this protocol or depended on those
  types must update accordingly.

These classes were never intended to be public, and were not documented, and are unlikely to have been used by anyone, but regardless this is strictly speaking a breaking change.
- class ChapterDiskCache has been removed
- class ChapterDownloadCache has been removed
- class VersionClient has been removed
- class VersionDiskCache has been removed
- class VersionDownloadCache has been removed
- class VersionMemoryCache has been removed
- constructor BibleVersionRepository.init(apiClient:memoryCache:diskCache:downloadCache:) has been removed
- protocol BibleVersionAPIClient has been removed
- protocol BibleVersionCaching has been removed
- var BibleVersionRepositoryProtocol.downloadedVersionIds has been added as a protocol requirement

* chore: remove unnecessary MainActor decoration, and improve an indent

* test: check before and after various changes are performed

* fix!: remove Observable from BibleVersionRepository and ObservableObject from BibleChapterRepository; they were not truly functional conformances anyway

* fix!: remove ObservableObject from BibleHighlightsViewModel; it wasn't ever functional anyway

* chore: continue previous change to BibleHighlightsViewModel

  YouVersionPlatformCore: 2 breaking changes
    - typealias BibleHighlightsViewModel.ObjectWillChangePublisher has been removed
    - class BibleHighlightsViewModel has removed conformance to ObservableObject

* chore: tidy, including changing parameter naming for internal functions

* chore: tidy, add internal protocol for more standard dependency injection

* test: use more standard injection mechanism, and rename to BibleVersionAPIRequestCounter

### Bug Fixes

* reader chrome hides/shows on scroll ([#96](https://github.com/youversion/platform-sdk-swift/issues/96)) ([f467a9b](https://github.com/youversion/platform-sdk-swift/commit/f467a9b692d950848c7feae80cadb51f1f5c42df))


### Code Refactoring

* SwiftUI idioms, naming guidelines ([#90](https://github.com/youversion/platform-sdk-swift/issues/90)) ([2935348](https://github.com/youversion/platform-sdk-swift/commit/293534854c0402e6e4fd6fea2298a934e8aa5a45)), closes [#87](https://github.com/youversion/platform-sdk-swift/issues/87)

## [4.9.1](https://github.com/youversion/platform-sdk-swift/compare/4.9.0...4.9.1) (2026-04-30)


### Bug Fixes

* follow device's dark/light color scheme inside BibleCardView's sheets ([9a101a7](https://github.com/youversion/platform-sdk-swift/commit/9a101a75f9a7d8d0eface0de4db52a3404cf1552))

## [4.9.0](https://github.com/youversion/platform-sdk-swift/compare/4.8.0...4.9.0) (2026-04-22)


### Features

* add (optional) version picking feature to BibleCard ([#84](https://github.com/youversion/platform-sdk-swift/issues/84)) ([656036d](https://github.com/youversion/platform-sdk-swift/commit/656036de69282a0d9981909cf61581103d6a45cc)), closes [#77](https://github.com/youversion/platform-sdk-swift/issues/77)

## [4.8.0](https://github.com/youversion/platform-sdk-swift/compare/4.7.0...4.8.0) (2026-04-20)


### Features

* make all animations aware of reduce motion setting and add corresponding lint rule ([967874f](https://github.com/youversion/platform-sdk-swift/commit/967874f676ae2db021d5e73ba5e5f5c150a44fab))

## [4.7.0](https://github.com/youversion/platform-sdk-swift/compare/4.6.0...4.7.0) (2026-04-20)


### Features

* update sample app to not use deprecated members ([bc5572b](https://github.com/youversion/platform-sdk-swift/commit/bc5572ba77ce0426386b5f5aa2792336b46b08a8))

## [4.6.0](https://github.com/youversion/platform-sdk-swift/compare/4.5.0...4.6.0) (2026-04-20)


### Features

* **reader:** improve verse actions animation and respect accessibility Reduce Motion setting ([#76](https://github.com/youversion/platform-sdk-swift/issues/76)) ([1e63e1e](https://github.com/youversion/platform-sdk-swift/commit/1e63e1e949db40c4e004ad50e1deb295f19ef418))

## [4.5.0](https://github.com/youversion/platform-sdk-swift/compare/4.4.0...4.5.0) (2026-04-17)


### Features

* **reader, ui:** make verse selection underline style configurable ([#69](https://github.com/youversion/platform-sdk-swift/issues/69)) ([7dd27bb](https://github.com/youversion/platform-sdk-swift/commit/7dd27bb33b25851fa1bb21031f489548d12452b4))

## [4.4.0](https://github.com/youversion/platform-sdk-swift/compare/4.3.0...4.4.0) (2026-04-16)


### Features

* **logging:** introduce YouVersionPlatformLogger to silence SDK console spam ([#70](https://github.com/youversion/platform-sdk-swift/issues/70)) ([06a794a](https://github.com/youversion/platform-sdk-swift/commit/06a794a895e3390643f3c6721298142b4ef30a9c))

## [4.3.0](https://github.com/youversion/platform-sdk-swift/compare/4.2.0...4.3.0) (2026-04-13)


### Features

* **reader:** add ability for clients to override behavior when user taps verse ([#67](https://github.com/youversion/platform-sdk-swift/issues/67)) ([6d0dd75](https://github.com/youversion/platform-sdk-swift/commit/6d0dd75177e189b4e2a752cfa789cf620d14958b))

## [4.2.0](https://github.com/youversion/platform-sdk-swift/compare/4.1.0...4.2.0) (2026-03-23)


### Features

* update Bible App logo ([a197689](https://github.com/youversion/platform-sdk-swift/commit/a1976896097754c43d56632d4c172d4d2bc0ca2d))

## [4.1.0](https://github.com/youversion/platform-sdk-swift/compare/4.0.5...4.1.0) (2026-03-12)


### Features

* support tvOS (except BibleReader) ([c2396fe](https://github.com/youversion/platform-sdk-swift/commit/c2396fe054b4545191473fa321b350fbb1adf481))

## [4.0.5](https://github.com/youversion/platform-sdk-swift/compare/4.0.4...4.0.5) (2026-03-12)


### Features

* change default BibleCard font to "STIX Two Text" ([1c514b0](https://github.com/youversion/platform-sdk-swift/commit/1c514b0f8c234ff4cfe6929347505c90f5533ee9))


### Bug Fixes

* size the footnote marker differently due to change in iOS 26.3.1 ([f1d1095](https://github.com/youversion/platform-sdk-swift/commit/f1d10956ef50b1734d2f71839b58c4980b498b9d))

## [4.0.4](https://github.com/youversion/platform-sdk-swift/compare/4.0.3...4.0.4) (2026-03-03)


### Bug Fixes

* adjust max-fields pageSize constant from 5 to 3 ([ec66388](https://github.com/youversion/platform-sdk-swift/commit/ec66388648c2ebea40d2f7b00253e2acea64385d))

## [4.0.3](https://github.com/youversion/platform-sdk-swift/compare/4.0.2...4.0.3) (2026-03-03)


### Bug Fixes

* move more localizable strings out of the code ([a941baa](https://github.com/youversion/platform-sdk-swift/commit/a941baa10ed200a44212726352b46a3da3dcaad5))

## [4.0.2](https://github.com/youversion/platform-sdk-swift/compare/4.0.1...4.0.2) (2026-03-02)


### Bug Fixes

* add Cancel button, and remove divider line below Chapters buttons ([3fcb552](https://github.com/youversion/platform-sdk-swift/commit/3fcb55213b51db9da4f1755bc0799ab139445bad))

## [4.0.1](https://github.com/youversion/platform-sdk-swift/compare/4.0.0...4.0.1) (2026-02-27)


### Bug Fixes

* adjust typography ([beebed6](https://github.com/youversion/platform-sdk-swift/commit/beebed675e58ffa9c8cc96027a9beb7361661e88))

## [4.0.0](https://github.com/youversion/platform-sdk-swift/compare/3.1.0...4.0.0) (2026-02-26)


### ⚠ BREAKING CHANGES

* renames BibleWidgetView to BibleCardView.

### Miscellaneous Chores

* rename BibleWidgetView to BibleCardView ([2d201a7](https://github.com/youversion/platform-sdk-swift/commit/2d201a7d7e066c10b171b3e7ec3b4adb42e5a984))

## [3.1.0](https://github.com/youversion/platform-sdk-swift/compare/3.0.0...3.1.0) (2026-02-25)


### Features

* also add highlight color underneath the verse labels ([ae69fea](https://github.com/youversion/platform-sdk-swift/commit/ae69fead51c2f88f619d5f6b50c3203b4110e0d7))

## [3.0.0](https://github.com/youversion/platform-sdk-swift/compare/2.0.5...3.0.0) (2026-02-25)


### ⚠ BREAKING CHANGES

* The onVerseTap callback of BibleTextView has an additional parameter: footnoteId. This allows the code to understand which footnote has been tapped, of possibly-multiple footnotes. That ID will match the id field of one of the items in the footnote list parameter.

### Features

* support Intro sections ([1577c74](https://github.com/youversion/platform-sdk-swift/commit/1577c744f25a18b10ac6163fbb084a23c334978d))

## [2.0.5](https://github.com/youversion/platform-sdk-swift/compare/2.0.4...2.0.5) (2026-02-24)


### Bug Fixes

* don't render headlines when they're at the end of a passage ([53f3158](https://github.com/youversion/platform-sdk-swift/commit/53f3158b9bcd49c3d2150dcd82e69bd42fa5461a))

## [2.0.4](https://github.com/youversion/platform-sdk-swift/compare/2.0.3...2.0.4) (2026-02-13)


### Bug Fixes

* BibleTextNode whitespace parsing ([63c6fad](https://github.com/youversion/platform-sdk-swift/commit/63c6fad4531fdf1ee8caac4538bf08ae83622842))

## [2.0.3](https://github.com/youversion/platform-sdk-swift/compare/2.0.2...2.0.3) (2026-02-13)


### Bug Fixes

* override font in the footnote text in the footnotesView also ([7a0bcd7](https://github.com/youversion/platform-sdk-swift/commit/7a0bcd753449f88b21c6c4f394131ad96cc0e7ac))

## [2.0.2](https://github.com/youversion/platform-sdk-swift/compare/2.0.1...2.0.2) (2026-02-13)


### Bug Fixes

* use BSB (3034) consistently as the default/preview Bible version ([62ee22a](https://github.com/youversion/platform-sdk-swift/commit/62ee22acbf13f82cdc622fc8b4af36a6135b8254))

## [2.0.1](https://github.com/youversion/platform-sdk-swift/compare/2.0.0...2.0.1) (2026-02-13)


### Bug Fixes

* adjust font family and size in footnotes popup ([2077641](https://github.com/youversion/platform-sdk-swift/commit/20776418c45985e701f4fd62c3ad570feaa387da))

## [2.0.0](https://github.com/youversion/platform-sdk-swift/compare/1.0.1...2.0.0) (2026-01-26)


### ⚠ BREAKING CHANGES

* the LanguageOverview struct's members now are all optional.

Access them now with the normal SwiftUI optional-chaining logic.
Reasoning: when you send the "fields[]" parameter to the UI, it will omit whatever fields weren't requested.

### Performance Improvements

* optimizes API calls getting the lists of Bible versions and language data ([0cb6579](https://github.com/youversion/platform-sdk-swift/commit/0cb6579628da903530ee668a0b2508ba67a9b422))

## [1.0.1](https://github.com/youversion/platform-sdk-swift/compare/1.0.0...1.0.1) (2025-12-22)


### Bug Fixes

* correct colors on the BibleReaderLanguagesView segmented picker ([91c770e](https://github.com/youversion/platform-sdk-swift/commit/91c770ea5c9f8de892673e10fcd7beab486cd7be))

## [1.0.0](https://github.com/youversion/platform-sdk-swift/compare/0.5.1...1.0.0) (2025-12-15)


### ⚠ BREAKING CHANGES

* remove outdated VersionView.swift and ship 1.0 (#28)

### Features

* remove outdated VersionView.swift and ship 1.0 ([#28](https://github.com/youversion/platform-sdk-swift/issues/28)) ([27674b2](https://github.com/youversion/platform-sdk-swift/commit/27674b21e28bbc4da50b206ea152e234cec4792c))

## [0.5.1](https://github.com/youversion/platform-sdk-swift/compare/0.5.0...0.5.1) (2025-12-09)


### Bug Fixes

* **reader:** adjust the Footnote marker image's size to match the font ([4693d37](https://github.com/youversion/platform-sdk-swift/commit/4693d3765939d3de079c7f96684e9e29c32d352c))

# [0.5.0](https://github.com/youversion/platform-sdk-swift/compare/0.4.0...0.5.0) (2025-12-08)


### Features

* **ui:** add footnoteImage option ([f8c91d8](https://github.com/youversion/platform-sdk-swift/commit/f8c91d859051a1d0c8766e5bc5513b95ef1c8709))

# [0.4.0](https://github.com/youversion/platform-sdk-swift/compare/0.3.0...0.4.0) (2025-12-08)


### Features

* **ui:** update Bible App logotype ([2bb116a](https://github.com/youversion/platform-sdk-swift/commit/2bb116abbed26c1f17af89df44983e781cb3dab0))

# [0.3.0](https://github.com/youversion/platform-sdk-swift/compare/0.2.0...0.3.0) (2025-12-05)


### Features

* **reader:** save and load remaining user settings e.g. fontFamily ([5078781](https://github.com/youversion/platform-sdk-swift/commit/50787818a89315db42a09c011c1251df03e492aa))

# [0.2.0](https://github.com/youversion/platform-sdk-swift/compare/0.1.1...0.2.0) (2025-12-03)


### Features

* **core:** use next_page_tokens to fetch all bibles and languages ([bba1b7e](https://github.com/youversion/platform-sdk-swift/commit/bba1b7e09951d663e7ab1859094a550f59a2a0e8))

## [0.1.1](https://github.com/youversion/platform-sdk-swift/compare/0.1.0...0.1.1) (2025-11-17)


### Bug Fixes

* **example:** add link to platform ([#11](https://github.com/youversion/platform-sdk-swift/issues/11)) ([6f8c5a0](https://github.com/youversion/platform-sdk-swift/commit/6f8c5a0c1914f99e93f19a3ae08c9204b9bc30c0))

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
