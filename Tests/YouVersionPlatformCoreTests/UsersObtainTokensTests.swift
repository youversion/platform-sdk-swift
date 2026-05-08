import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct UsersObtainTokensTests {

    @Test func obtainTokensSuccessDecodesResponse() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let payload: [String: Any] = [
            "access_token": "access-token",
            "expires_in": "3600",
            "id_token": "header.payload.signature",
            "refresh_token": "refresh-token",
            "scope": "bibles,highlights",
            "token_type": "Bearer"
        ]
        let responseData = try JSONSerialization.data(withJSONObject: payload)

        HTTPMocking.setHandler(token: token) { request in
            #expect(request.httpMethod == "POST")
            let body = requestBodyString(request)
            #expect(body.contains("code=auth-code"))
            #expect(body.contains("code_verifier=verifier"))
            #expect(body.contains("redirect_uri=youversionauth://callback"))
            #expect(body.contains("grant_type=authorization_code"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }

        let tokens = try await YouVersionAPI.Users.obtainTokens(
            from: "auth-code",
            codeVerifier: "verifier",
            redirectUri: "youversionauth://callback",
            session: session
        )

        #expect(tokens.accessToken == "access-token")
        #expect(tokens.refreshToken == "refresh-token")
        #expect(tokens.scope == "bibles,highlights")
    }

    @Test func obtainTokensUnexpectedStatusThrows() async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: URLError.self) {
            _ = try await YouVersionAPI.Users.obtainTokens(
                from: "auth-code",
                codeVerifier: "verifier",
                redirectUri: "youversionauth://callback",
                session: session
            )
        }
    }

    @Test func obtainTokens400InvalidGrantThrows() async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let errorBody = """
        {"error": "invalid_grant"}
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (errorBody, response)
        }

        await #expect(throws: URLError(.badServerResponse)) {
            _ = try await YouVersionAPI.Users.obtainTokens(
                from: "bad-code",
                codeVerifier: "verifier",
                redirectUri: "youversionauth://callback",
                session: session
            )
        }
    }

    @Test func obtainTokens401UnauthorizedThrows() async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: URLError(.badServerResponse)) {
            _ = try await YouVersionAPI.Users.obtainTokens(
                from: "auth-code",
                codeVerifier: "verifier",
                redirectUri: "youversionauth://callback",
                session: session
            )
        }
    }
}
