import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

extension ConfigurationStateTests {
    @Suite struct DataExchangeAPITests {
        
        @Test func permissionRawValueAndDescription() {
            #expect(DataExchangePermission.highlights.rawValue == "highlights")
            #expect(DataExchangePermission.highlights.description == "highlights")
            #expect(DataExchangePermission(rawValue: "notes") == .unknown("notes"))
            #expect(DataExchangePermission(rawValue: "notes").rawValue == "notes")
        }
        
        @MainActor
        @Test func tokenSuccessCreatesRequestAndReturnsToken() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            YouVersionPlatformConfiguration.clearAuthTokens()
            YouVersionPlatformConfiguration.configure(appKey: "test-app-key")
            defer {
                YouVersionPlatformConfiguration.clearAuthTokens()
                YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            }
            
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            
            let responseData = """
        {"token":"data-exchange-token"}
        """.data(using: .utf8)!
            var capturedRequest: URLRequest?
            
            HTTPMocking.setHandler(token: token) { request in
                capturedRequest = request
                let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
                return (responseData, response)
            }
            
            let result = try await YouVersionAPI.DataExchange.updateToken(
                withPermissions: [.highlights],
                accessToken: "access-token",
                session: session
            )
            
            let request = try #require(capturedRequest)
            let components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
            let queryItems = components.queryItems ?? []
            let body = try JSONDecoder().decode(Body.self, from: Data(requestBodyString(request).utf8))
            
            #expect(result.token == "data-exchange-token")
            #expect(request.httpMethod == "POST")
            #expect(components.path == "/data-exchange/token")
            #expect(queryItems.first { $0.name == "app-key" }?.value == "test-app-key")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-token")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: HTTPMocking.tokenHeader) == token)
            #expect(body.permissions == ["highlights"])
        }
        
        @MainActor
        @Test func tokenMissingAppKeyThrowsMissingAuthentication() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            YouVersionPlatformConfiguration.configure(appKey: nil)
            defer {
                YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            }
            
            await #expect(throws: YouVersionAPIError.missingAuthentication) {
                _ = try await YouVersionAPI.DataExchange.updateToken(
                    withPermissions: [.highlights],
                    accessToken: "access-token"
                )
            }
        }
        
        @MainActor
        @Test func tokenMissingAccessTokenThrowsMissingAuthentication() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            YouVersionPlatformConfiguration.clearAuthTokens()
            YouVersionPlatformConfiguration.configure(appKey: "test-app-key")
            defer {
                YouVersionPlatformConfiguration.clearAuthTokens()
                YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            }
            
            await #expect(throws: YouVersionAPIError.missingAuthentication) {
                _ = try await YouVersionAPI.DataExchange.updateToken(withPermissions: [.highlights])
            }
        }
        
        @MainActor
        @Test func tokenUnauthorizedThrowsNotPermitted() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            YouVersionPlatformConfiguration.configure(appKey: "test-app-key")
            defer {
                YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            }
            
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            
            HTTPMocking.setHandler(token: token) { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }
            
            await #expect(throws: YouVersionAPIError.notPermitted) {
                _ = try await YouVersionAPI.DataExchange.updateToken(
                    withPermissions: [.highlights],
                    accessToken: "access-token",
                    session: session
                )
            }
        }
        
        @MainActor
        @Test func tokenUnexpectedStatusThrowsCannotDownload() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            YouVersionPlatformConfiguration.configure(appKey: "test-app-key")
            defer {
                YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            }
            
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            
            HTTPMocking.setHandler(token: token) { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }
            
            await #expect(throws: YouVersionAPIError.cannotDownload) {
                _ = try await YouVersionAPI.DataExchange.updateToken(
                    withPermissions: [.highlights],
                    accessToken: "access-token",
                    session: session
                )
            }
        }
        
        @MainActor
        @Test func tokenNonHTTPResponseThrowsInvalidResponse() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            YouVersionPlatformConfiguration.configure(appKey: "test-app-key")
            defer {
                YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            }
            
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            
            HTTPMocking.setHandler(token: token) { request in
                let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
                return (Data(), response)
            }
            
            await #expect(throws: YouVersionAPIError.invalidResponse) {
                _ = try await YouVersionAPI.DataExchange.updateToken(
                    withPermissions: [.highlights],
                    accessToken: "access-token",
                    session: session
                )
            }
        }
        
        @MainActor
        @Test func tokenMalformedJSONThrowsDecodingError() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            YouVersionPlatformConfiguration.configure(appKey: "test-app-key")
            defer {
                YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            }
            
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            
            HTTPMocking.setHandler(token: token) { request in
                let malformedJSON = "{ invalid json }".data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
                return (malformedJSON, response)
            }
            
            await #expect(throws: DecodingError.self) {
                _ = try await YouVersionAPI.DataExchange.updateToken(
                    withPermissions: [.highlights],
                    accessToken: "access-token",
                    session: session
                )
            }
        }
        
        private struct Body: Decodable {
            let permissions: [String]

            enum CodingKeys: String, CodingKey {
                case permissions = "requested_permissions"
            }
        }
    }
}
