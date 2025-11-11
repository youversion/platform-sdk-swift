import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct VOTDTests {

    @MainActor
    @Test func votdSuccessDecodes() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"human":"John 3:16","abbreviation":"KJV","text":"For God so loved...","copyright":"(c)"}
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let v = try await YouVersionAPI.VOTD.verseOfTheDay(versionId: 1, session: session)
        #expect(v.reference == "John 3:16")
        #expect(v.abbreviation == "KJV")
        #expect(v.text.contains("For God so loved"))
    }

    @MainActor
    @Test func votdUnauthorizedThrowsNotPermitted() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: BibleVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(versionId: 1, session: session)
        }
    }

    @MainActor
    @Test func votdServerErrorThrowsCannotDownload() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: BibleVersionAPIError.cannotDownload) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(versionId: 1, session: session)
        }
    }

    @MainActor
    @Test func votdInvalidResponseThrowsInvalidResponse() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        }

        await #expect(throws: BibleVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(versionId: 1, session: session)
        }
    }

    @MainActor
    @Test func votdMalformedJSONThrowsBadServerResponse() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let malformed = "{ bad json }".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (malformed, response)
        }

        await #expect(throws: URLError.self) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(versionId: 1, session: session)
        }
    }

    @MainActor
    @Test func votdRequestSetsAppKeyHeader() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"human":"John 3:16","abbreviation":"KJV","text":"For God so loved...","copyright":"(c)"}
        """.data(using: .utf8)!
        var captured: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let _ = try await YouVersionAPI.VOTD.verseOfTheDay(versionId: 99, session: session)
        let req = try #require(captured)
        #expect(req.value(forHTTPHeaderField: "x-yvp-app-key") == "app")
        #expect(req.url?.absoluteString.contains("version=99") == true)
    }
}
