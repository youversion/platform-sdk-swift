import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct BibleVersionsAPITests {

    @MainActor
    @Test func versionsSuccessReturnsDecodedOverviews() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"data": [
            {"id": 1, "title": "English Version", "abbreviation": "en", "language": "en"},
            {"id": 2, "title": "German Version", "abbreviation": "de", "language": "de"}
        ]}
        """.data(using: .utf8)!
        var capturedRequest: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            #expect(queryItems.contains(where: { $0.name == "language_ranges" && $0.value == "en" }))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let versions = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", session: session)

        #expect(versions.count == 2)
        #expect(versions.first?.id == 1)
        let _ = try #require(capturedRequest)
    }

    @MainActor
    @Test func versionsUnauthorizedThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: BibleVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", session: session)
        }
    }

    @MainActor
    @Test func versionsUnexpectedStatusThrowsCannotDownload() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: BibleVersionAPIError.cannotDownload) {
            _ = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", session: session)
        }
    }

    @MainActor
    @Test func versionsInvalidResponseThrows() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        }

        await #expect(throws: BibleVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", session: session)
        }
    }
}
