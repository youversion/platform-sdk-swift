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
            {"id": 1, "title": "English Version", "abbreviation": "en", "language_tag": "en"},
            {"id": 2, "title": "German Version", "abbreviation": "de", "language_tag": "de"}
        ]}
        """.data(using: .utf8)!
        var capturedRequest: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            #expect(queryItems.contains(where: { $0.name == "language_ranges[]" && $0.value == "en" }))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let versions = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)

        #expect(versions.count == 2)
        #expect(versions.first?.id == 1)
        #expect(versions.first?.languageTag == "en")
        #expect(versions.last?.languageTag == "de")
        let _ = try #require(capturedRequest)
    }

    @MainActor
    @Test func permittedVersionsSuccessReturnsMinimalInfo() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"data": [
            {"id": 1, "title": "English Version", "abbreviation": "eng", "language_tag": "en"},
            {"id": 2, "title": "German Version", "abbreviation": "deu", "language_tag": "de"}
        ]}
        """.data(using: .utf8)!
        var capturedRequest: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let versions = try await YouVersionAPI.Bible.permittedVersions(
            forLanguageTag: "en",
            accessToken: "swift-test-suite",
            session: session
        )

        #expect(versions == [
            YouVersionAPI.Bible.BibleVersionMinimalInfo(id: 1, languageTag: "en"),
            YouVersionAPI.Bible.BibleVersionMinimalInfo(id: 2, languageTag: "de")
        ])

        let request = try #require(capturedRequest)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        #expect(queryItems.contains(where: { $0.name == "language_ranges[]" && $0.value == "en" }))
        #expect(queryItems.contains(where: { $0.name == "page_size" && $0.value == "*" }))
        #expect(queryItems.contains(where: { $0.name == "fields[]" && $0.value == "id" }))
        #expect(queryItems.contains(where: { $0.name == "fields[]" && $0.value == "language_tag" }))
    }

    @MainActor
    @Test func permittedVersionsDefaultsToAllLanguages() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"data": [
            {"id": 1, "language_tag": "en"}
        ]}
        """.data(using: .utf8)!
        var capturedRequest: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let versions = try await YouVersionAPI.Bible.permittedVersions(accessToken: "swift-test-suite", session: session)

        #expect(versions == [YouVersionAPI.Bible.BibleVersionMinimalInfo(id: 1, languageTag: "en")])
        let request = try #require(capturedRequest)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        #expect(queryItems.contains(where: { $0.name == "language_ranges[]" && $0.value == "*" }))
        #expect(queryItems.contains(where: { $0.name == "page_size" && $0.value == "*" }))
        #expect(queryItems.contains(where: { $0.name == "fields[]" && $0.value == "id" }))
        #expect(queryItems.contains(where: { $0.name == "fields[]" && $0.value == "language_tag" }))
    }

    @MainActor
    @Test func permittedVersionsUnauthorizedThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.Bible.permittedVersions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func permittedVersionsForbiddenThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.Bible.permittedVersions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func permittedVersionsUnexpectedStatusThrowsCannotDownload() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.cannotDownload) {
            _ = try await YouVersionAPI.Bible.permittedVersions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func permittedVersionsInvalidResponseThrows() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.Bible.permittedVersions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func versionsUnauthorizedThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)
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

        await #expect(throws: YouVersionAPIError.cannotDownload) {
            _ = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)
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

        await #expect(throws: YouVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func versionsPaginationCombinesBothPages() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let page1 = """
        {"data": [
            {"id": 1, "title": "Version One", "language_tag": "en"}
        ], "next_page_token": "token-abc"}
        """.data(using: .utf8)!

        let page2 = """
        {"data": [
            {"id": 2, "title": "Version Two", "language_tag": "en"}
        ]}
        """.data(using: .utf8)!

        var requestCount = 0

        HTTPMocking.setHandler(token: token) { request in
            requestCount += 1
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if requestCount == 1 {
                #expect(!queryItems.contains(where: { $0.name == "page_token" }))
                return (page1, response)
            } else {
                #expect(queryItems.contains(where: { $0.name == "page_token" && $0.value == "token-abc" }))
                return (page2, response)
            }
        }

        let versions = try await YouVersionAPI.Bible.versions(forLanguageTag: "en", accessToken: "swift-test-suite", session: session)

        #expect(requestCount == 2)
        #expect(versions.count == 2)
        #expect(versions[0].id == 1)
        #expect(versions[1].id == 2)
    }
}
