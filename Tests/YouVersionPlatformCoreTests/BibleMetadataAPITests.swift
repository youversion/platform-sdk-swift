import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct BibleMetadataAPITests {

    @MainActor
    @Test func metadataSuccessReturnsData() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let expectedData = """
        {"id": 206, "title": "Test Version", "abbreviation": "TV", "language_tag": "en"}
        """.data(using: .utf8)!
        var capturedRequest: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (expectedData, response)
        }

        let version = try await YouVersionAPI.Bible.basicVersion(versionId: 206, accessToken: "swift-test-suite", session: session)

        #expect(version.id == 206)
        let _ = try #require(capturedRequest)
    }

    @MainActor
    @Test func metadataForbiddenThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.Bible.version(versionId: 206, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func metadataUnexpectedStatusThrowsCannotDownload() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.cannotDownload) {
            _ = try await YouVersionAPI.Bible.version(versionId: 206, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func metadataInvalidResponseThrows() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.Bible.version(versionId: 206, accessToken: "swift-test-suite", session: session)
        }
    }
}
