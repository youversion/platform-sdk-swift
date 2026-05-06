import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

@Suite struct BibleVersionSearchFilterTests {
    @Test func emptyQueryReturnsAll() {
        let versions = [
            makeVersion(id: 1, title: "English Standard Version", abbreviation: "ESV", languageTag: "en"),
            makeVersion(id: 2, title: "Nueva Versión Internacional", abbreviation: "NVI", languageTag: "es"),
        ]
        #expect(filteredBibleVersions(versions, matching: "") == versions)
    }

    @Test func whitespaceOnlyQueryReturnsAll() {
        let versions = [makeVersion(id: 1, title: "King James Version", abbreviation: "KJV", languageTag: "en")]
        #expect(filteredBibleVersions(versions, matching: "   \t\n") == versions)
    }

    @Test func queryWithSurroundingSpacesMatchesAsIfTrimmed() {
        let kjv = makeVersion(id: 1, title: "King James Version", abbreviation: "KJV", languageTag: "en")
        let esv = makeVersion(id: 2, title: "English Standard Version", abbreviation: "ESV", languageTag: "en")
        #expect(filteredBibleVersions([kjv, esv], matching: " king ") == [kjv])
    }

    @Test func matchesTitleCaseInsensitively() {
        let kjv = makeVersion(id: 1, title: "King James Version", abbreviation: "KJV", languageTag: "en")
        let esv = makeVersion(id: 2, title: "English Standard Version", abbreviation: "ESV", languageTag: "en")

        #expect(filteredBibleVersions([kjv, esv], matching: "king") == [kjv])
        #expect(filteredBibleVersions([kjv, esv], matching: "KING") == [kjv])
        #expect(filteredBibleVersions([kjv, esv], matching: "standard") == [esv])
    }

    @Test func matchesAbbreviationCaseInsensitively() {
        let kjv = makeVersion(id: 1, title: "King James Version", abbreviation: "KJV", languageTag: "en")
        let nvi = makeVersion(id: 2, title: "Nueva Versión Internacional", abbreviation: "NVI", languageTag: "es")

        #expect(filteredBibleVersions([kjv, nvi], matching: "kjv") == [kjv])
        #expect(filteredBibleVersions([kjv, nvi], matching: "KJV") == [kjv])
        #expect(filteredBibleVersions([kjv, nvi], matching: "nvi") == [nvi])
    }

    @Test func matchesLanguageTagCaseInsensitively() {
        let english = makeVersion(id: 1, title: "Bible", abbreviation: "BIB", languageTag: "en")
        let spanish = makeVersion(id: 2, title: "Biblia", abbreviation: "BIB", languageTag: "es")
        let chineseTraditional = makeVersion(id: 3, title: "聖經", abbreviation: "CT", languageTag: "zh-TW")

        #expect(filteredBibleVersions([english, spanish], matching: "en") == [english])
        #expect(filteredBibleVersions([english, spanish], matching: "es") == [spanish])
        // Mixed-case tag: searching "TW" lowercases to "tw", must still match "zh-TW"
        #expect(filteredBibleVersions([english, chineseTraditional], matching: "TW") == [chineseTraditional])
    }

    @Test func nilTitleMatchedAsEmpty() {
        let version = makeVersion(id: 1, title: nil, abbreviation: "TST", languageTag: "en")
        #expect(filteredBibleVersions([version], matching: "tst") == [version])
        #expect(filteredBibleVersions([version], matching: "anything").isEmpty)
    }

    @Test func nilAbbreviationFallsBackToVersionId() {
        let version = makeVersion(id: 1234, title: "Test Version", abbreviation: nil, languageTag: "en")
        #expect(filteredBibleVersions([version], matching: "1234") == [version])
    }

    @Test func noMatchReturnsEmpty() {
        let versions = [makeVersion(id: 1, title: "King James Version", abbreviation: "KJV", languageTag: "en")]
        #expect(filteredBibleVersions(versions, matching: "xyz").isEmpty)
    }

    @Test func queryMatchingMultipleFieldsIncludesVersionOnce() {
        // title and abbreviation both contain "test" — version should appear once
        let version = makeVersion(id: 1, title: "Test Bible", abbreviation: "TEST", languageTag: "en")
        #expect(filteredBibleVersions([version], matching: "test") == [version])
    }

    @Test func emptyVersionListReturnsEmpty() {
        #expect(filteredBibleVersions([], matching: "anything").isEmpty)
    }

    // MARK: -

    private func makeVersion(id: Int, title: String?, abbreviation: String?, languageTag: String?) -> BibleVersion {
        BibleVersion(
            id: id,
            abbreviation: abbreviation,
            promotionalContent: nil,
            copyright: nil,
            languageTag: languageTag,
            localizedAbbreviation: nil,
            localizedTitle: nil,
            readerFooter: nil,
            readerFooterUrl: nil,
            title: title,
            organizationId: nil,
            bookCodes: nil,
            books: nil,
            textDirection: nil
        )
    }
}
