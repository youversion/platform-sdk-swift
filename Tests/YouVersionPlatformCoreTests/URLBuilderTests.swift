import Foundation
import Testing
@testable import YouVersionPlatformCore

@MainActor
struct URLBuilderTests {

    @Test
    func testAuthURLs() throws {
        let url = try #require(URLBuilder.authorizeURL(queryItems: [
            URLQueryItem(name: "state", value: "stateValue"),
        ]))
        #expect(url.absoluteString == "https://api.youversion.com/auth/authorize?state=stateValue")
    }

    @Test
    func testBibleURLs() throws {
        // Configure using defaults (no host environment)

        // Test /v1/bibles endpoints
        let version = try #require(URLBuilder.versionURL(versionId: 2))
        #expect(version.absoluteString == "https://api.youversion.com/v1/bibles/2")

        let versionBooks = try #require(URLBuilder.versionBooksURL(versionId: 1))
        #expect(versionBooks.absoluteString == "https://api.youversion.com/v1/bibles/1/books")

        let bookChapters = try #require(URLBuilder.versionBookChaptersURL(versionId: 1, book: "GEN"))
        #expect(bookChapters.absoluteString == "https://api.youversion.com/v1/bibles/1/books/GEN/chapters")

        let versions = try #require(URLBuilder.versionsURL(languageRanges: ["en"]))
        #expect(versions.absoluteString == "https://api.youversion.com/v1/bibles?language_ranges%5B%5D=en&page_size=99")

        // Test /v1/bibles/{versionId}/passages endpoints
        let reference = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
        let passage = try #require(URLBuilder.passageURL(reference: reference))
        #expect(passage.absoluteString == "https://api.youversion.com/v1/bibles/1/passages/GEN.1?format=text&include_notes=true&include_headings=true")

        let passageJson = try #require(URLBuilder.passageURL(reference: reference, format: "json"))
        #expect(passageJson.absoluteString == "https://api.youversion.com/v1/bibles/1/passages/GEN.1?format=json&include_notes=true&include_headings=true")
    }

    @Test
    func testVOTDURLs() throws {
        // Configure using defaults (no host environment)

        let votd = try #require(URLBuilder.votdURL(dayOfYear: 5))
        #expect(votd.absoluteString == "https://api.youversion.com/v1/verse_of_the_days/5")
    }

    @Test
    func testHighlightsURLs() throws {
        // Configure using defaults (no host environment)

        let baseHighlights = try #require(URLBuilder.highlightsURL)
        #expect(baseHighlights.absoluteString == "https://api.youversion.com/v1/highlights")

        let highlights = try #require(URLBuilder.highlightsURL(bibleId: 1, passageId: "GEN.1"))
        #expect(highlights.absoluteString == "https://api.youversion.com/v1/highlights?bible_id=1&passage_id=GEN.1")

        let highlightsDelete = try #require(URLBuilder.highlightsDeleteURL(bibleId: 1, passageId: "GEN.1"))
        #expect(highlightsDelete.absoluteString == "https://api.youversion.com/v1/highlights/GEN.1?bible_id=1")
    }

    @Test
    func testHighlightsDeleteURLWithHyphenatedPassageId() throws {
        // Hyphens are valid URL path characters (RFC 3986), so a verse-range passageId like
        // "GEN.1.3-GEN.1.5" is safe to interpolate directly into the path.
        // Note: only URL-path-safe passageIds are supported; the source does not percent-encode
        // the passageId before embedding it in the path segment.
        let url = try #require(URLBuilder.highlightsDeleteURL(bibleId: 1, passageId: "GEN.1.3-GEN.1.5"))
        #expect(url.absoluteString == "https://api.youversion.com/v1/highlights/GEN.1.3-GEN.1.5?bible_id=1")
        #expect(url.path.contains("GEN.1.3-GEN.1.5"))
    }

    @Test
    func testLanguagesURLs() throws {
        // Configure using defaults (no host environment)

        let languages = try #require(URLBuilder.languagesURL(country: "US"))
        #expect(languages.absoluteString == "https://api.youversion.com/v1/languages?page_size=99&country=US")

        let languagesNoCountry = try #require(URLBuilder.languagesURL(country: nil))
        #expect(languagesNoCountry.absoluteString == "https://api.youversion.com/v1/languages?page_size=99")
    }
}
