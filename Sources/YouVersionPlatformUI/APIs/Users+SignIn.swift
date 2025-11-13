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
            preconditionFailure("YouVersionPlatformConfiguration.appKey must be set")
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
                            let location = try await obtainCode(callbackURL, state: authorizationRequest.parameters.state)
                            let code = try codeFromLocationURL(location)
                            let result = try await obtainToken(code: code, codeVerifier: authorizationRequest.parameters.codeVerifier)
                            //YouVersionPlatformConfiguration.setAccessToken(result.accessToken)
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

    static func obtainCode(_ callbackURL: URL, state: String) async throws -> String {
        /*
         The callbackURL will look like this:
         youversionauth://callback?profile_picture=whatever.com/t.png&state=Onfdpf&user_email=daf%40xyz.com&user_name=David&yvp_id=c98a
         */
        guard var components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
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

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 302 else {
            throw URLError(.badServerResponse)
        }
        guard let location = httpResponse.value(forHTTPHeaderField: "Location") else {
            throw URLError(.badServerResponse)
        }
        return location
    }

    static func codeFromLocationURL(_ location: String) throws -> String {
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

    static func obtainToken(code: String, codeVerifier: String) async throws -> SignInWithYouVersionResult {
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

        let responseObject = try JSONDecoder().decode(TokenResponse.self, from: data)
        return SignInWithYouVersionResult(
            accessToken: responseObject.accessToken,
            expiresIn: responseObject.expiresIn,
            refreshToken: responseObject.refreshToken,
            permissions: [],
            yvpUserId: ""
        )
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
        return nil // disable following redirects
    }
}

#endif
