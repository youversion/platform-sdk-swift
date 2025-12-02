#if canImport(AuthenticationServices)
import AuthenticationServices
import Foundation
import YouVersionPlatformCore

public extension YouVersionAPI.Users {

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

        let redirectURL = URL(string: "youversionauth://callback")!
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
                            let result = try await YouVersionAPI.Users.getSignInResult(
                                from: callbackURL,
                                state: authorizationRequest.parameters.state,
                                codeVerifier: authorizationRequest.parameters.codeVerifier,
                                redirectUri: redirectURL.absoluteString,
                                nonce: authorizationRequest.parameters.nonce
                            )
                            YouVersionPlatformConfiguration.saveAuthData(
                                accessToken: result.accessToken,
                                refreshToken: result.refreshToken,
                                idToken: result.idToken,
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
}

#endif
