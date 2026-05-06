import Testing
@testable import YouVersionPlatformUI

@Suite struct LanguageTagSorterTests {
    // MARK: - sortedUniqueLanguageTags

    @Test func emptyInputReturnsEmpty() {
        #expect(sortedUniqueLanguageTags([], languageName: { $0 }).isEmpty)
    }

    @Test func singleTagReturnsSingleTag() {
        #expect(sortedUniqueLanguageTags(["en"], languageName: { _ in "English" }) == ["en"])
    }

    @Test func deduplicatesDuplicateTags() {
        let result = sortedUniqueLanguageTags(["en", "en", "es"], languageName: { $0 })
        #expect(result.count == 2)
        #expect(Set(result) == Set(["en", "es"]))
    }

    @Test func sortsByDisplayName() {
        let names = ["en": "English", "fr": "French", "ar": "Arabic"]
        let result = sortedUniqueLanguageTags(["en", "fr", "ar"], languageName: { names[$0] ?? $0 })
        #expect(result == ["ar", "en", "fr"])
    }

    @Test func sortIsCaseInsensitive() {
        let names = ["a": "Zebra", "b": "apple", "c": "Mango"]
        let result = sortedUniqueLanguageTags(["a", "b", "c"], languageName: { names[$0] ?? $0 })
        // localizedCaseInsensitiveCompare: apple < Mango < Zebra
        #expect(result == ["b", "c", "a"])
    }

    @Test func deduplicatesBeforeSorting() {
        // Three copies of "en", one of "fr" — dedup should leave two unique tags
        let names = ["en": "English", "fr": "French"]
        let result = sortedUniqueLanguageTags(["en", "en", "fr", "en"], languageName: { names[$0] ?? $0 })
        #expect(result == ["en", "fr"])
    }

    @Test func fallsBackToTagWhenNameReturnsItself() {
        // languageName returns the tag — sort should use the tag string itself
        let result = sortedUniqueLanguageTags(["zh", "en", "ar"], languageName: { $0 })
        #expect(result == ["ar", "en", "zh"])
    }

    // MARK: - filterLanguageTags

    @Test func emptySearchReturnsAllTags() {
        let tags = ["en", "es", "fr"]
        #expect(filteredLanguageTags(tags, matching: "", languageName: { $0 }) == tags)
    }

    @Test func whitespaceOnlySearchReturnsAllTags() {
        let tags = ["en", "es", "fr"]
        #expect(filteredLanguageTags(tags, matching: "   \t\n", languageName: { $0 }) == tags)
    }

    @Test func queryWithSurroundingSpacesMatchesAsIfTrimmed() {
        let tags = ["en", "es", "fr"]
        let names = ["en": "English", "es": "Español", "fr": "French"]
        #expect(filteredLanguageTags(tags, matching: " French ", languageName: { names[$0] ?? $0 }) == ["fr"])
    }

    @Test func matchesTagCaseInsensitively() {
        let tags = ["en", "zh-TW", "ar"]
        let names = ["en": "English", "zh-TW": "Chinese Traditional", "ar": "Arabic"]
        let name: (String) -> String = { names[$0] ?? $0 }

        #expect(filteredLanguageTags(tags, matching: "EN", languageName: name) == ["en"])
        #expect(filteredLanguageTags(tags, matching: "zh", languageName: name) == ["zh-TW"])
    }

    @Test func matchesDisplayNameCaseInsensitively() {
        let tags = ["en", "es", "fr"]
        let names = ["en": "English", "es": "Español", "fr": "French"]
        let name: (String) -> String = { names[$0] ?? $0 }

        #expect(filteredLanguageTags(tags, matching: "french", languageName: name) == ["fr"])
        #expect(filteredLanguageTags(tags, matching: "ENGLISH", languageName: name) == ["en"])
    }

    @Test func noMatchReturnsEmpty() {
        let tags = ["en", "es", "fr"]
        #expect(filteredLanguageTags(tags, matching: "xyz", languageName: { $0 }).isEmpty)
    }

    @Test func queryMatchingAllTagsReturnsAll() {
        let tags = ["en-US", "en-GB", "en-AU"]
        let result = filteredLanguageTags(tags, matching: "en", languageName: { $0 })
        #expect(result == tags)
    }

    @Test func emptyTagListReturnsEmpty() {
        #expect(filteredLanguageTags([], matching: "en", languageName: { $0 }).isEmpty)
    }
}
