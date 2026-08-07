import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

extension ConfigurationStateTests {
    @Suite(.serialized) struct UsersAuthHelpersTests {

        @Test func obtainCodeReturnsAuthorizationCode() throws {
            let location = "youversionauth://callback?state=xyz&code=abc123&scope=bibles"

            let code = try YouVersionAPI.Users.obtainCode(from: location)

            #expect(code == "abc123")
        }

        @Test func obtainCodeMissingAuthorizationCodeThrows() {
            let location = "youversionauth://callback?state=xyz"

            #expect(throws: URLError.self) {
                _ = try YouVersionAPI.Users.obtainCode(from: location)
            }
        }

        @Test func extractResultParsesClaimsAndPermissions() throws {
            let callbackURL = URL(string: "youversionauth://callback")!
            let payload: [String: Any] = [
                "sub": "user-123",
                "name": "Test User",
                "profile_picture": "https://example.com/avatar.png",
                "email": "user@example.com",
                "nonce": "xyz"
            ]
            let token = try makeTestJWT(claims: payload)

            let tokens = YouVersionAPI.Users.TokenResponse(
                accessToken: "access-token",
                expiresIn: "3600",
                idToken: token,
                refreshToken: "refresh-token",
                scope: "openid,email,profile",
                tokenType: "Bearer"
            )

            let result = try YouVersionAPI.Users.extractSignInWithYouVersionResult(
                from: tokens,
                nonce: "xyz",
                callbackURL: callbackURL
            )

            #expect(result.accessToken == "access-token")
            #expect(result.refreshToken == "refresh-token")
            #expect(result.idToken == token)
            #expect(result.permissionValues == ["openid", "email", "profile"])
            #expect(result.yvpUserId == "user-123")
            #expect(result.name == "Test User")
            #expect(result.profilePicture == "https://example.com/avatar.png")
            #expect(result.email == "user@example.com")
        }

        @Test func extractResultMergesGrantedPermissionsFromCallbackURL() throws {
            let callbackURL = URL(string: "youversionauth://callback?granted_permissions=highlights")!
            let token = try makeTestJWT(claims: ["nonce": "xyz"])
            let tokens = makeTokenResponse(idToken: token, scope: "openid,email")

            let result = try YouVersionAPI.Users.extractSignInWithYouVersionResult(
                from: tokens,
                nonce: "xyz",
                callbackURL: callbackURL
            )

            #expect(Set(result.permissionValues) == Set(["openid", "email", "highlights"]))
        }

        @Test func extractResultMergesRepeatedGrantedPermissionsFromCallbackURL() throws {
            let callbackURL = URL(
                string: "youversionauth://callback?granted_permissions=highlights&granted_permissions=notes"
            )!
            let token = try makeTestJWT(claims: ["nonce": "xyz"])
            let tokens = makeTokenResponse(idToken: token, scope: "openid,email")

            let result = try YouVersionAPI.Users.extractSignInWithYouVersionResult(
                from: tokens,
                nonce: "xyz",
                callbackURL: callbackURL
            )

            #expect(Set(result.permissionValues) == Set(["openid", "email", "highlights", "notes"]))
        }

        @Test func extractResultUsesTokenScopePermissionsWhenCallbackDoesNotIncludeGrantedPermissions() throws {
            let callbackURL = URL(string: "youversionauth://callback?code=abc123")!
            let token = try makeTestJWT(claims: ["nonce": "xyz"])
            let tokens = makeTokenResponse(idToken: token, scope: "openid,email")

            let result = try YouVersionAPI.Users.extractSignInWithYouVersionResult(
                from: tokens,
                nonce: "xyz",
                callbackURL: callbackURL
            )

            #expect(result.permissionValues == ["openid", "email"])
        }

        @Test func extractResultPreservesUnknownGrantedPermissionsFromCallbackURL() throws {
            let callbackURL = URL(string: "youversionauth://callback?granted_permissions=unknown,highlights")!
            let token = try makeTestJWT(claims: ["nonce": "xyz"])
            let tokens = makeTokenResponse(idToken: token, scope: "openid,email")

            let result = try YouVersionAPI.Users.extractSignInWithYouVersionResult(
                from: tokens,
                nonce: "xyz",
                callbackURL: callbackURL
            )

            #expect(Set(result.permissionValues) == Set(["openid", "email", "highlights", "unknown"]))
        }

        @Test func extractResultFailsBadNonce() throws {
            let callbackURL = URL(string: "youversionauth://callback")!
            let payload: [String: Any] = [
                "sub": "user-123",
                "name": "Test User",
                "profile_picture": "https://example.com/avatar.png",
                "email": "user@example.com",
                "nonce": "BADVALUE"
            ]
            let token = try makeTestJWT(claims: payload)

            let tokens = YouVersionAPI.Users.TokenResponse(
                accessToken: "access-token",
                expiresIn: "3600",
                idToken: token,
                refreshToken: "refresh-token",
                scope: "openid,email,profile",
                tokenType: "Bearer"
            )

            #expect(throws: URLError.self) {
                _ = try YouVersionAPI.Users.extractSignInWithYouVersionResult(
                    from: tokens,
                    nonce: "xyz",
                    callbackURL: callbackURL
                )
            }
        }
    }

    @Suite(.serialized) struct RefreshSignInTests {

        @Test func refreshSignInSuccessReturnsNewTokens() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: "test-app")

            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }

            let responsePayload: [String: String] = [
                "access_token": "new-access",
                "expires_in": "7200",
                "refresh_token": "new-refresh",
                "scope": "openid,email"
            ]
            let responseData = try JSONEncoder().encode(responsePayload)

            HTTPMocking.setHandler(token: token) { request in
                #expect(request.url?.path == "/auth/token")
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
                let body = requestBodyString(request)
                #expect(body.contains("grant_type=refresh_token"))
                #expect(body.contains("client_id=test-app"))
                #expect(body.contains("refresh_token=refresh-token-value"))

                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (responseData, response)
            }

            let result = try await YouVersionAPI.Users.refreshSignIn(
                withToken: "refresh-token-value",
                idToken: "id-token",
                session: session
            )

            #expect(result.accessToken == "new-access")
            #expect(result.refreshToken == "new-refresh")
            #expect(result.idToken == "id-token")
            #expect(result.permissionValues == ["openid", "email"])
            #expect(result.yvpUserId == nil)

            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }

        @Test func refreshSignInNon200Throws() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: "test-app")

            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }

            HTTPMocking.setHandler(token: token) { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }

            await #expect(throws: URLError.self) {
                _ = try await YouVersionAPI.Users.refreshSignIn(
                    withToken: "refresh-token-value",
                    idToken: nil,
                    session: session
                )
            }

            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
    }
}

private func makeTokenResponse(idToken: String, scope: String) -> YouVersionAPI.Users.TokenResponse {
    YouVersionAPI.Users.TokenResponse(
        accessToken: "access-token",
        expiresIn: "3600",
        idToken: idToken,
        refreshToken: "refresh-token",
        scope: scope,
        tokenType: "Bearer"
    )
}

private func makeTestJWT(claims: [String: Any]) throws -> String {
    let header = ["alg": "RS256", "typ": "JWT"]
    let headerData = try JSONSerialization.data(withJSONObject: header)
    let payloadData = try JSONSerialization.data(withJSONObject: claims)
    let headerSegment = base64URLEncodedString(headerData)
    let payloadSegment = base64URLEncodedString(payloadData)
    return "\(headerSegment).\(payloadSegment).signature"
}

private func base64URLEncodedString(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
