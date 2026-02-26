# Changelog

All notable changes to this project will be documented in this file.

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
