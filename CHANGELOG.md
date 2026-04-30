# Changelog

All notable changes to this project will be documented in this file.

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
