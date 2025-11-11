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
    ///   - requiredPermissions: The set of permissions that must be granted by the user for successful login.
    ///   - optionalPermissions: The set of permissions that will be requested from the user but are not required for successful login.
    ///   - contextProvider: The presentation context provider used for presenting the authentication session.
    ///
    /// - Returns: A ``YouVersionLoginResult`` containing the authorization code and granted permissions upon successful login.
    ///
    /// - Throws: An error if authentication fails or is cancelled by the user.
    @MainActor
    static func signIn(
        requiredPermissions: Set<SignInWithYouVersionPermission>,
        optionalPermissions: Set<SignInWithYouVersionPermission>,
        contextProvider: ASWebAuthenticationPresentationContextProviding
    ) async throws -> SignInWithYouVersionResult {
        guard let appKey = YouVersionPlatformConfiguration.appKey else {
            preconditionFailure("YouVersionPlatformConfiguration.appKey must be set")
        }

        guard let url = URLBuilder.authURL(
            appKey: appKey,
            requiredPermissions: requiredPermissions,
            optionalPermissions: optionalPermissions
        ) else {
            throw URLError(.badURL)
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SignInWithYouVersionResult, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "youversionauth"
            ) { callbackURL, error in
                Task { @MainActor in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL {
                        do {
                            let result = try SignInWithYouVersionResult(url: callbackURL)
                            YouVersionPlatformConfiguration.setAccessToken(result.accessToken)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
            }
            // TODO: add the install id here once the server handles it.
            //let request = URLRequest.youVersion(url)
            //session.additionalHeaderFields = request.allHTTPHeaderFields
            session.presentationContextProvider = contextProvider
            session.start()
        }
    }
}
#endif
