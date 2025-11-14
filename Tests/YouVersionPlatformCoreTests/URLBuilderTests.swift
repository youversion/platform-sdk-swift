import Foundation
import Testing
@testable import YouVersionPlatformCore

@MainActor
struct URLBuilderTests {

    @Test
    func testAuthURLs() throws {
        // Configure without host environment

        // userURL uses access token query
        let user = try #require(URLBuilder.userURL(accessToken: "token"))
        #expect(user.absoluteString == "https://api.youversion.com/auth/me?lat=token")

        // authURL should include required and optional permissions plus install id
        let auth = try #require(URLBuilder.authURL(appKey: "appKey", requiredPermissions: [.bibles], optionalPermissions: [.highlights]))
        let components = try #require(URLComponents(url: auth, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        #expect(items.first { $0.name == "required_perms" }?.value == "bibles")
        #expect(items.first { $0.name == "opt_perms" }?.value == "highlights")
        #expect(items.first { $0.name == "x-yvp-installation-id" }?.value == YouVersionPlatformConfiguration.installId)
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
        #expect(versions.absoluteString == "https://api.youversion.com/v1/bibles?language_ranges%5B%5D=en&page_size=25")

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
    func testLanguagesURLs() throws {
        // Configure using defaults (no host environment)

        let languages = try #require(URLBuilder.languagesURL(country: "US"))
        #expect(languages.absoluteString == "https://api.youversion.com/v1/languages?page_size=25&country=US")

        let languagesNoCountry = try #require(URLBuilder.languagesURL(country: nil))
        #expect(languagesNoCountry.absoluteString == "https://api.youversion.com/v1/languages?page_size=25")
    }
}
