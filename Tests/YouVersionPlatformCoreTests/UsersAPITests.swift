import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct UsersAPITests {

    @MainActor
    @Test func userInfoPreviewReturnsPreview() async throws {
        // No network should be hit for preview token
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let info = try await YouVersionAPI.Users.userInfo(accessToken: "preview", session: session)
        #expect(info.firstName == "John")
        #expect(info.lastName == "Smith")
        #expect(info.userId == "12345")
        #expect(info.avatarUrl == nil)
    }

    @MainActor
    @Test func userInfoSuccessReturnsDecoded() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"id":"u1","first_name":"Alice","last_name":"Doe","avatar_url":"//cdn.example.com/avatar_{width}x{height}.jpg"}
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let info = try await YouVersionAPI.Users.userInfo(accessToken: "token", session: session)
        #expect(info.userId == "u1")
        #expect(info.firstName == "Alice")
        #expect(info.lastName == "Doe")
        let url = try #require(info.avatarUrl)
        #expect(url.absoluteString == "https://cdn.example.com/avatar_200x200.jpg")
    }

    @MainActor
    @Test func userInfoUnauthorizedThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.Users.userInfo(accessToken: "token", session: session)
        }
    }

    @MainActor
    @Test func userInfoUnexpectedStatusThrowsCannotDownload() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.cannotDownload) {
            _ = try await YouVersionAPI.Users.userInfo(accessToken: "token", session: session)
        }
    }

    @MainActor
    @Test func userInfoInvalidResponseThrowsInvalidResponse() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.Users.userInfo(accessToken: "token", session: session)
        }
    }

    @MainActor
    @Test func userInfoProvidedTokenOverridesConfigAndSetsHeader() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"id":"u2","first_name":"Bob","last_name":"Ross"}
        """.data(using: .utf8)!
        var captured: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let _ = try await YouVersionAPI.Users.userInfo(accessToken: "explicit", session: session)
        let request = try #require(captured)
        let comps = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        let items = comps.queryItems ?? []
        #expect(items.first { $0.name == "lat" }?.value == "explicit")
    }

    @MainActor
    @Test func userInfoNilTokenUsesConfiguredAccessToken() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"id":"u3","first_name":"Carol","last_name":"Danvers"}
        """.data(using: .utf8)!
        var captured: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let _ = try await YouVersionAPI.Users.userInfo(session: session)
        let request = try #require(captured)
        let _ = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
    }

    @MainActor
    @Test func userInfoMalformedJSONThrowsBadServerResponse() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let malformed = "{ bad json }".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (malformed, response)
        }

        await #expect(throws: URLError.self) {
            _ = try await YouVersionAPI.Users.userInfo(accessToken: "token", session: session)
        }
    }
}


