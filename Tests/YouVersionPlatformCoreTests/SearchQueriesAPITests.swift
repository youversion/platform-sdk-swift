import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct SearchQueriesAPITests {
    @Test
    func suggestedQueriesSendParametersAndDecodeCollection() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {
          "data": [
            {"text":"whom shall I fear","source":"community"},
            {"text":"whom have I in heaven","source":null}
          ]
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

        let results = try await YouVersionAPI.Search.suggestedQueries(
            matching: "whom",
            languageRanges: ["en-US", "es"],
            accessToken: "swift-test-suite",
            session: session
        )

        let request = try #require(capturedRequest)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let languageRanges = components.queryItems?
            .filter { $0.name == "language_ranges[]" }
            .compactMap(\.value)
        #expect(components.path == "/v1-beta/search-queries")
        #expect(languageRanges == ["en-US", "es"])
        #expect(components.queryItems?.contains(URLQueryItem(name: "query", value: "whom")) == true)
        #expect(components.queryItems?.contains(where: { $0.name == "trending" }) == false)
        #expect(results.queries.map(\.text) == ["whom shall I fear", "whom have I in heaven"])
        #expect(results.queries.first?.source == "community")
    }

    @Test
    func trendingQueriesSendTrendingParameterWithoutQuery() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"data":[{"text":"love","source":"trending"}]}
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

        let results = try await YouVersionAPI.Search.trendingQueries(
            languageRanges: ["en"],
            accessToken: "swift-test-suite",
            session: session
        )

        let request = try #require(capturedRequest)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(URLQueryItem(name: "trending", value: "true")) == true)
        #expect(components.queryItems?.contains(where: { $0.name == "query" }) == false)
        #expect(results.queries.map(\.text) == ["love"])
    }

    @Test
    func noContentReturnsEmptyCollection() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        let results = try await YouVersionAPI.Search.trendingQueries(
            languageRanges: ["en"],
            accessToken: "swift-test-suite",
            session: session
        )

        #expect(results.queries.isEmpty)
    }

    @Test
    func invalidParametersReturnInvalidParameterError() async {
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.suggestedQueries(matching: "", languageRanges: ["en"])
        }
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.suggestedQueries(matching: "love", languageRanges: [])
        }
        await #expect(throws: YouVersionAPIRequestError(code: .invalidParameter)) {
            try await YouVersionAPI.Search.trendingQueries(languageRanges: [""])
        }
    }
}
