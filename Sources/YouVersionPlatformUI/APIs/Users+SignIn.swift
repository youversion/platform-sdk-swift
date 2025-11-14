#if canImport(AuthenticationServices)
import AuthenticationServices
import Foundation
import YouVersionPlatformCore

public extension YouVersionAPI.Users {
    static let redirectURL = URL(string: "youversionauth://callback")!

    /// Presents the YouVersion login flow to the user and returns the login result upon completion.
    ///
    /// This function uses `ASWebAuthenticationSession` to authenticate the user with YouVersion, requesting the specified required and optional permissions.
    /// The function suspends until the user completes or cancels the login flow, returning the login result containing the authorization code and granted permissions.
    ///
    /// - Parameters:
    ///   - permissions: The set of permissions to request from the user for login.
    ///   - contextProvider: The presentation context provider used for presenting the authentication session.
    ///
    /// - Returns: A ``YouVersionLoginResult`` containing the authorization code and granted permissions upon successful login.
    ///
    /// - Throws: An error if authentication fails or is cancelled by the user.
    @MainActor
    static func signIn(
        permissions: Set<SignInWithYouVersionPermission>,
        contextProvider: ASWebAuthenticationPresentationContextProviding
    ) async throws -> SignInWithYouVersionResult {
        guard let appKey = YouVersionPlatformConfiguration.appKey else {
            throw YouVersionAPIError.missingAuthentication
        }

        let authorizationRequest = try SignInWithYouVersionPKCEAuthorizationRequestBuilder.make(
            appKey: appKey,
            permissions: permissions,
            redirectURL: redirectURL
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SignInWithYouVersionResult, Error>) in
            let session = ASWebAuthenticationSession(
                url: authorizationRequest.url,
                callbackURLScheme: redirectURL.scheme!
            ) { callbackURL, error in
                Task { @MainActor in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL {
                        do {
                            let location = try await obtainLocation(from: callbackURL, state: authorizationRequest.parameters.state)
                            let code = try obtainCode(from: location)
                            let tokens = try await obtainTokens(from: code, codeVerifier: authorizationRequest.parameters.codeVerifier)
                            let result = try extractSignInWithYouVersionResult(from: tokens)
                            YouVersionPlatformConfiguration.saveAuthData(
                                accessToken: result.accessToken,
                                refreshToken: result.refreshToken,
                                expiryDate: result.expiryDate
                            )
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
            }
            session.presentationContextProvider = contextProvider
            session.start()
        }
    }

    static func obtainLocation(from callbackURL: URL, state: String) async throws -> String {
        /*
         The callbackURL will look like this:
         youversionauth://callback?profile_picture=whatever.com/t.png&state=Onfdpf&user_email=daf%40xyz.com&user_name=David&yvp_id=c98a
         */
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              queryItems.first(where: { $0.name == "state" })?.value == state
        else {
            throw URLError(.badURL)
        }

        var newComponents = URLComponents(string: "https://api-staging.youversion.com/auth/callback")!
        newComponents.queryItems = queryItems  //.filter { $0.name != "state" }
        guard let newURL = newComponents.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: newURL)
        request.httpMethod = "GET"
        let session = URLSession(configuration: .default, delegate: RedirectDisabler(), delegateQueue: nil)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 302 else {
            throw URLError(.badServerResponse)
        }
        guard let location = httpResponse.value(forHTTPHeaderField: "Location") else {
            throw URLError(.badServerResponse)
        }
        return location
    }

    static func obtainCode(from location: String) throws -> String {
        guard let locationUrl = URL(string: location),
              let locationComponents = URLComponents(url: locationUrl, resolvingAgainstBaseURL: false),
              let locationQueryItems = locationComponents.queryItems,
              //locationQueryItems.first(where: { $0.name == "state" })?.value == state,
              let codeQueryItem = locationQueryItems.first(where: { $0.name == "code" }),
              let code = codeQueryItem.value
        else {
            throw URLError(.badServerResponse)
        }
        return code
    }

    static func obtainTokens(from code: String, codeVerifier: String) async throws -> TokenResponse {
        let request = try SignInWithYouVersionPKCEAuthorizationRequestBuilder.tokenURLRequest(
            code: code,
            codeVerifier: codeVerifier,
            redirectUri: redirectURL.absoluteString
        )

        let session = URLSession(configuration: .default)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if httpResponse.statusCode != 200 {
            print("obtainToken got status: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    static func extractSignInWithYouVersionResult(from tokens: TokenResponse) throws -> SignInWithYouVersionResult {
        let idClaims = try decodeJWT(tokens.idToken)
        let permissions = tokens.scope
            .split(separator: ",")
            .compactMap { SignInWithYouVersionPermission(rawValue: String($0)) }
        return SignInWithYouVersionResult(
            accessToken: tokens.accessToken,
            expiresIn: tokens.expiresIn,
            refreshToken: tokens.refreshToken,
            permissions: permissions,
            yvpUserId: idClaims["sub"] as? String,
            name: idClaims["sub"] as? String,
            profilePicture: idClaims["profile_picture"] as? String,
            email: idClaims["email"] as? String,
        )
    }

    static func decodeJWT(_ token: String) throws -> [String: Any] {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else {
            return [:]
        }
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let ret = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return ret
    }

    struct TokenResponse: Codable, Sendable, Equatable {
        public let accessToken: String
        public let expiresIn: String
        public let idToken: String
        public let refreshToken: String
        public let scope: String
        public let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case idToken = "id_token"
            case refreshToken = "refresh_token"
            case scope
            case tokenType = "token_type"
        }
    }

}

private final class RedirectDisabler: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil // disable following redirects
    }
}

#endif
