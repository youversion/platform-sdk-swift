import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct SearchTopicsAPITests {
    @Test
    func topicsSendParametersAndDecodeCollection() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {
          "topics": [
            {"id":42,"text":"Faith","subtopics":["trust","belief"]},
            {"id":null,"text":"Love","subtopics":[]}
          ],
          "did_you_mean": ["faith"],
          "search_instead_for": "faith",
          "total_size": 2
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

        let results = try await YouVersionAPI.Search.topics(
            matching: "faif",
            languageRanges: ["en-US", "*"],
            accessToken: "swift-test-suite",
            session: session
        )

        let request = try #require(capturedRequest)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let languageRanges = components.queryItems?
            .filter { $0.name == "language_ranges[]" }
            .compactMap(\.value)
        #expect(components.path == "/v1-beta/search-topics")
        #expect(components.queryItems?.contains(URLQueryItem(name: "query", value: "faif")) == true)
        #expect(languageRanges == ["en-US", "*"])
        #expect(results.topics.map(\.id) == [42, nil])
        #expect(results.topics.map(\.text) == ["Faith", "Love"])
        #expect(results.topics.first?.subtopics == ["trust", "belief"])
        #expect(results.topics.last?.subtopics == [])
        #expect(results.didYouMean == ["faith"])
        #expect(results.searchInsteadFor == "faith")
        #expect(results.totalSize == 2)
    }

    @Test
    func invalidParametersReturnInvalidParameterError() async {
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.topics(matching: "", languageRanges: ["en"])
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.topics(
                matching: String(repeating: "a", count: 101),
                languageRanges: ["en"]
            )
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.topics(matching: "love", languageRanges: [])
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.topics(matching: "love", languageRanges: [""])
        }
        await #expect(throws: YouVersionAPIRequestError.self) {
            try await YouVersionAPI.Search.topics(matching: "love", languageRanges: ["en--US"])
        }
    }
}
