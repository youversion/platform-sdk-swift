import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct BibleSearchAPITests {
    @Test
    func searchVersesSendsParametersAndDecodesCollection() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {
          "verses": [
            {"reference":"MAT.14.17"},
            {"reference":"JHN.6.9"}
          ],
          "user_intent": "text",
          "did_you_mean": ["two fishes"],
          "search_instead_for": null,
          "next_page_token": "next-token"
        }
        """.data(using: .utf8)!

        var capturedRequest: URLRequest?
        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (json, response)
        }

        let results = try await YouVersionAPI.Search.verses(
            query: "two fish",
            bibleID: 111,
            userIntent: .text,
            pageSize: 25,
            pageToken: "current-token",
            accessToken: "swift-test-suite",
            session: session
        )

        let request = try #require(capturedRequest)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        #expect(components.path == "/v1-beta/search-verses")
        #expect(components.queryItems?.contains(URLQueryItem(name: "query", value: "two fish")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "bible_id", value: "111")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "user_intent", value: "text")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "page_size", value: "25")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "page_token", value: "current-token")) == true)
        #expect(results.verses.map(\.reference) == ["MAT.14.17", "JHN.6.9"])
        #expect(results.userIntent == .text)
        #expect(results.didYouMean == ["two fishes"])
        #expect(results.searchInsteadFor == nil)
        #expect(results.nextPageToken == "next-token")
    }

    @Test
    func responsePreservesFutureUserIntentValues() throws {
        let json = """
        {
          "verses": [],
          "user_intent": "future-intent",
          "did_you_mean": [],
          "search_instead_for": null
        }
        """.data(using: .utf8)!

        let results = try JSONDecoder().decode(YouVersionVerseSearchResults.self, from: json)
        let roundTrippedResults = try JSONDecoder().decode(
            YouVersionVerseSearchResults.self,
            from: JSONEncoder().encode(results)
        )

        #expect(results.userIntent?.rawValue == "future-intent")
        #expect(roundTrippedResults.userIntent?.rawValue == "future-intent")
    }

    @Test
    func verseResultConvertsValidUSFMToReference() throws {
        let result = YouVersionVerseSearchResult(reference: "JHN.3.16")
        let reference = try #require(result.bibleReference(versionID: 111))

        #expect(reference == BibleReference(versionId: 111, bookId: "JHN", chapter: 3, verse: 16))
        #expect(YouVersionVerseSearchResult(reference: "JHN.3").bibleReference(versionID: 111) == nil)
    }

    @Test
    func invalidParametersReturnInvalidParameterError() async {
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.verses(query: "", bibleID: 111)
        }
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.verses(query: String(repeating: "a", count: 101), bibleID: 111)
        }
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.verses(query: "love", bibleID: 0)
        }
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.verses(query: "love", bibleID: -1)
        }
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.verses(query: "love", bibleID: Int(Int32.max) + 1)
        }
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.verses(query: "love", bibleID: 111, pageSize: 0)
        }
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.verses(query: "love", bibleID: 111, pageSize: 100)
        }
    }
}
