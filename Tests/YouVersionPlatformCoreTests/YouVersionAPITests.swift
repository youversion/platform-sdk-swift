import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

extension ConfigurationStateTests {
    @Suite(.serialized) struct YouVersionAPITests {
        @Test func hasValidTokenReturnsFalseWithoutStoredAuthData() async {
            await YouVersionPlatformConfiguration.clearAuthTokens()

            let hasValidToken = await YouVersionAPI.hasValidToken()

            #expect(hasValidToken == false)
        }

        @Test func hasValidTokenReturnsTrueForUnexpiredTokenWithoutRefreshing() async {
            await YouVersionPlatformConfiguration.saveAuthData(
                accessToken: "access-token",
                refreshToken: "refresh-token",
                idToken: "id-token",
                expiryDate: Date(timeIntervalSinceNow: 3600)
            )

            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }

            HTTPMocking.setHandler(token: token) { _ in
                Issue.record("Expected hasValidToken not to refresh an unexpired token")
                throw URLError(.badURL)
            }

            let hasValidToken = await YouVersionAPI.hasValidToken(session: session)

            #expect(hasValidToken == true)
            #expect(YouVersionPlatformConfiguration.authData?.accessToken == "access-token")

            await YouVersionPlatformConfiguration.clearAuthTokens()
        }

        @Test func hasValidTokenRefreshesExpiringTokenAndStoresResponse() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            let responsePayload: [String: String] = [
                "access_token": "new-access-token",
                "expires_in": "7200",
                "refresh_token": "new-refresh-token",
                "scope": "ignored"
            ]
            let responseData = try JSONEncoder().encode(responsePayload)

            await YouVersionPlatformConfiguration.configure(appKey: "test-app")
            await YouVersionPlatformConfiguration.saveAuthData(
                accessToken: "old-access-token",
                refreshToken: "old-refresh-token",
                idToken: "id-token",
                expiryDate: Date(timeIntervalSinceNow: 5)
            )

            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }

            HTTPMocking.setHandler(token: token) { request in
                #expect(request.url?.path == "/auth/token")
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
                let body = requestBodyString(request)
                #expect(body.contains("grant_type=refresh_token"))
                #expect(body.contains("client_id=test-app"))
                #expect(body.contains("refresh_token=old-refresh-token"))

                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (responseData, response)
            }

            let hasValidToken = await YouVersionAPI.hasValidToken(session: session)
            let authData = YouVersionPlatformConfiguration.authData

            #expect(hasValidToken == true)
            #expect(authData?.accessToken == "new-access-token")
            #expect(authData?.refreshToken == "new-refresh-token")
            #expect(authData?.idToken == "id-token")
            #expect((authData?.expiryDate?.timeIntervalSinceNow ?? 0) > 7100)

            await YouVersionPlatformConfiguration.clearAuthTokens()
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }

        @Test func authenticatedRequestWaitsForSharedTokenRefresh() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            let responsePayload: [String: String] = [
                "access_token": "new-access-token",
                "expires_in": "7200",
                "refresh_token": "new-refresh-token",
                "scope": "highlights"
            ]
            let responseData = try JSONEncoder().encode(responsePayload)

            await YouVersionPlatformConfiguration.configure(appKey: "test-app")
            await YouVersionPlatformConfiguration.saveAuthData(
                accessToken: "expired-access-token",
                refreshToken: "old-refresh-token",
                idToken: "id-token",
                expiryDate: Date(timeIntervalSinceNow: -60),
                permissions: ["highlights"]
            )

            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            var refreshRequestCount = 0
            var highlightsAuthorizationHeader: String?

            HTTPMocking.setHandler(token: token) { request in
                switch request.url?.path {
                case "/auth/token":
                    refreshRequestCount += 1
                    Thread.sleep(forTimeInterval: 0.1)
                    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                    return (responseData, response)
                case "/v1/highlights":
                    highlightsAuthorizationHeader = request.value(forHTTPHeaderField: "Authorization")
                    let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
                    return (Data(), response)
                default:
                    throw URLError(.badURL)
                }
            }

            async let tokenIsValid = YouVersionAPI.hasValidToken(session: session)
            async let highlights = YouVersionAPI.Highlights.highlights(
                bibleId: 1,
                passageId: "GEN.1",
                session: session
            )
            let (isValid, loadedHighlights) = try await (tokenIsValid, highlights)

            #expect(isValid)
            #expect(loadedHighlights.isEmpty)
            #expect(refreshRequestCount == 1)
            #expect(highlightsAuthorizationHeader == "Bearer new-access-token")

            await YouVersionPlatformConfiguration.clearAuthTokens()
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }

        @Test func hasValidTokenReturnsFalseWhenRefreshFails() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: "test-app")
            await YouVersionPlatformConfiguration.saveAuthData(
                accessToken: "old-access-token",
                refreshToken: "old-refresh-token",
                idToken: "id-token",
                expiryDate: Date(timeIntervalSinceNow: 5)
            )

            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }

            HTTPMocking.setHandler(token: token) { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }

            let hasValidToken = await YouVersionAPI.hasValidToken(session: session)

            #expect(hasValidToken == false)
            #expect(YouVersionPlatformConfiguration.authData?.accessToken == "old-access-token")

            await YouVersionPlatformConfiguration.clearAuthTokens()
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
    }
}
