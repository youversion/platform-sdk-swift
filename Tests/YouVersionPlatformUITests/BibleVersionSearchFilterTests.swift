import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

@Suite struct BibleVersionSearchFilterTests {
    @Test func emptyQueryReturnsAll() {
        let versions = [
            makeVersion(id: 1, title: "English Standard Version", abbreviation: "ESV", languageTag: "en"),
            makeVersion(id: 2, title: "Nueva Versión Internacional", abbreviation: "NVI", languageTag: "es"),
        ]
        #expect(filterBibleVersions(versions, matching: "") == versions)
    }

    @Test func whitespaceOnlyQueryReturnsAll() {
        let versions = [makeVersion(id: 1, title: "King James Version", abbreviation: "KJV", languageTag: "en")]
        #expect(filterBibleVersions(versions, matching: "   \t\n") == versions)
    }

    @Test func matchesTitleCaseInsensitively() {
        let kjv = makeVersion(id: 1, title: "King James Version", abbreviation: "KJV", languageTag: "en")
        let esv = makeVersion(id: 2, title: "English Standard Version", abbreviation: "ESV", languageTag: "en")

        #expect(filterBibleVersions([kjv, esv], matching: "king") == [kjv])
        #expect(filterBibleVersions([kjv, esv], matching: "KING") == [kjv])
        #expect(filterBibleVersions([kjv, esv], matching: "standard") == [esv])
    }

    @Test func matchesAbbreviationCaseInsensitively() {
        let kjv = makeVersion(id: 1, title: "King James Version", abbreviation: "KJV", languageTag: "en")
        let nvi = makeVersion(id: 2, title: "Nueva Versión Internacional", abbreviation: "NVI", languageTag: "es")

        #expect(filterBibleVersions([kjv, nvi], matching: "kjv") == [kjv])
        #expect(filterBibleVersions([kjv, nvi], matching: "KJV") == [kjv])
        #expect(filterBibleVersions([kjv, nvi], matching: "nvi") == [nvi])
    }

    @Test func matchesLanguageTag() {
        let english = makeVersion(id: 1, title: "Bible", abbreviation: "BIB", languageTag: "en")
        let spanish = makeVersion(id: 2, title: "Biblia", abbreviation: "BIB", languageTag: "es")

        #expect(filterBibleVersions([english, spanish], matching: "en") == [english])
        #expect(filterBibleVersions([english, spanish], matching: "es") == [spanish])
    }

    @Test func nilTitleMatchedAsEmpty() {
        let version = makeVersion(id: 1, title: nil, abbreviation: "TST", languageTag: "en")
        #expect(filterBibleVersions([version], matching: "tst") == [version])
        #expect(filterBibleVersions([version], matching: "anything").isEmpty)
    }

    @Test func nilAbbreviationFallsBackToVersionId() {
        let version = makeVersion(id: 1234, title: "Test Version", abbreviation: nil, languageTag: "en")
        #expect(filterBibleVersions([version], matching: "1234") == [version])
    }

    @Test func noMatchReturnsEmpty() {
        let versions = [makeVersion(id: 1, title: "King James Version", abbreviation: "KJV", languageTag: "en")]
        #expect(filterBibleVersions(versions, matching: "xyz").isEmpty)
    }

    @Test func queryMatchingMultipleFieldsIncludesVersionOnce() {
        // title and abbreviation both contain "test" — version should appear once
        let version = makeVersion(id: 1, title: "Test Bible", abbreviation: "TEST", languageTag: "en")
        #expect(filterBibleVersions([version], matching: "test") == [version])
    }

    @Test func emptyVersionListReturnsEmpty() {
        #expect(filterBibleVersions([], matching: "anything").isEmpty)
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
