import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct VOTDTests {

    @MainActor
    @Test func votdSuccessDecodes() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"day":1,"passage_id":"JHN.3.16"}
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let v = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        #expect(v.passageId == "JHN.3.16")
        #expect(v.day == 1)
    }

    @MainActor
    @Test func votdUnauthorizedThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func votdServerErrorThrowsCannotDownload() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.cannotDownload) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func votdInvalidResponseThrowsInvalidResponse() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func votdMalformedJSONThrowsBadServerResponse() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let malformed = "{ bad json }".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (malformed, response)
        }

        await #expect(throws: URLError.self) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func votdRequestSetsAppKeyHeader() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"day":99,"passage_id":"MAT.5.1"}
        """.data(using: .utf8)!
        var captured: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 99, accessToken: "swift-test-suite", session: session)
        let req = try #require(captured)
        #expect(req.url?.absoluteString.contains("/99") == true)
    }
}
