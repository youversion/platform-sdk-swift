import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct SearchResultsAPITests {
    @Test
    func resultsSendParametersAndDecodeCollection() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {
          "verses": [
            {"reference":"JHN.3.16"},
            {"reference":"1CO.13.4"}
          ],
          "topics": [
            {"id":42,"text":"Love","subtopics":["kindness","patience"]},
            {"id":null,"text":"Faith","subtopics":[]}
          ],
          "user_intent": "topical",
          "did_you_mean": ["loved"],
          "search_instead_for": "love"
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

        let results = try await YouVersionAPI.Search.results(
            matching: "luv",
            bibleID: 111,
            languageRanges: ["en-US", "*"],
            userIntent: .topical,
            fields: ["verses", "topics"],
            accessToken: "swift-test-suite",
            session: session
        )

        let request = try #require(capturedRequest)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let languageRanges = components.queryItems?
            .filter { $0.name == "language_ranges[]" }
            .compactMap(\.value)
        let fields = components.queryItems?
            .filter { $0.name == "fields[]" }
            .compactMap(\.value)
        #expect(components.path == "/v1-beta/search-results")
        #expect(components.queryItems?.contains(URLQueryItem(name: "query", value: "luv")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "bible_id", value: "111")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "user_intent", value: "topical")) == true)
        #expect(languageRanges == ["en-US", "*"])
        #expect(fields == ["verses", "topics"])
        #expect(results.verses.map(\.reference) == ["JHN.3.16", "1CO.13.4"])
        #expect(results.topics.map(\.id) == [42, nil])
        #expect(results.topics.map(\.text) == ["Love", "Faith"])
        #expect(results.topics.first?.subtopics == ["kindness", "patience"])
        #expect(results.topics.last?.subtopics == [])
        #expect(results.userIntent == .topical)
        #expect(results.didYouMean == ["loved"])
        #expect(results.searchInsteadFor == "love")
    }

    @Test
    func defaultParametersRequestAllResultKinds() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {
          "verses": [],
          "topics": [],
          "user_intent": null,
          "did_you_mean": [],
          "search_instead_for": null
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

        _ = try await YouVersionAPI.Search.results(
            matching: "love",
            bibleID: 111,
            languageRanges: ["en"],
            accessToken: "swift-test-suite",
            session: session
        )

        let request = try #require(capturedRequest)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(URLQueryItem(name: "user_intent", value: "unknown")) == true)
        #expect(components.queryItems?.contains(where: { $0.name == "fields[]" }) == false)
    }

    @Test
    func invalidParametersReturnInvalidParameterError() async {
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.results(matching: "", bibleID: 111, languageRanges: ["en"])
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.results(
                matching: String(repeating: "a", count: 101),
                bibleID: 111,
                languageRanges: ["en"]
            )
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.results(matching: "love", bibleID: 0, languageRanges: ["en"])
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.results(matching: "love", bibleID: -1, languageRanges: ["en"])
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.results(
                matching: "love",
                bibleID: Int(Int32.max) + 1,
                languageRanges: ["en"]
            )
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.results(matching: "love", bibleID: 111, languageRanges: [])
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.results(matching: "love", bibleID: 111, languageRanges: [""])
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.results(matching: "love", bibleID: 111, languageRanges: ["en--US"])
        }
    }
}
