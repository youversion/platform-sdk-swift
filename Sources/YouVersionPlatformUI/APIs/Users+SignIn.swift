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
                        performLoopTwo(callbackURL, authorizationRequest: authorizationRequest, continuation: continuation)
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
            }
            session.presentationContextProvider = contextProvider
            session.start()
        }
    }

    @MainActor
    static func performLoopTwo(
        _ callbackURL: URL,
        authorizationRequest: SignInWithYouVersionPKCEAuthorizationRequest,
        continuation: CheckedContinuation<SignInWithYouVersionResult, Error>
    ) {
        do {
            print("LoopTwo with URL: \(callbackURL)")
            /*
             The callbackURL will look like this:
             youversionauth://callback?profile_picture=whatever.com/t.png&state=Onfdpf&user_email=daf%40xyz.com&user_name=David&yvp_id=c98a
             */
            guard var components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems,
                  queryItems.first(where: { $0.name == "state" })?.value == authorizationRequest.parameters.state
            else {
                continuation.resume(throwing: URLError(.badURL))
                return
            }

            var newComponents = URLComponents(string: "https://api-staging.youversion.com/auth/callback")!
            newComponents.queryItems = queryItems  //.filter { $0.name != "state" }

            guard let newURL = newComponents.url else {
                continuation.resume(throwing: URLError(.badURL))
                return
            }

            Task {
                do {
                    var request = URLRequest(url: newURL)
                    request.httpMethod = "GET"

                    let session = URLSession(configuration: .default, delegate: RedirectDisabler(), delegateQueue: nil)
                    let (data, response) = try await session.data(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }

                    guard httpResponse.statusCode == 302,
                          let location = httpResponse.value(forHTTPHeaderField: "Location") else {
                        continuation.resume(throwing: URLError(.redirectToNonExistentLocation))
                        return
                    }

                    await performLoopThree(location: location, authorizationRequest: authorizationRequest, continuation: continuation)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            continuation.resume(throwing: error)
        }
    }

    @MainActor
    static func performLoopThree(
        location: String,
        authorizationRequest: SignInWithYouVersionPKCEAuthorizationRequest,
        continuation: CheckedContinuation<SignInWithYouVersionResult, Error>
    ) async {
        do {
            print("LoopThree with location: \(location)")
            let request = try SignInWithYouVersionPKCEAuthorizationRequestBuilder.tokenURLRequest(
                location: location,
                codeVerifier: authorizationRequest.parameters.codeVerifier,
                redirectUri: redirectURL.absoluteString
            )

            print("LoopThree is POSTing: \(request.url?.absoluteString ?? "")")
            let session = URLSession(configuration: .default)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                continuation.resume(throwing: URLError(.badServerResponse))
                return
            }

            print("POST response status: \(httpResponse.statusCode)")
            print("POST response body: \(String(data: data, encoding: .utf8) ?? "")")

            //let result = try SignInWithYouVersionResult(url: callbackURL)
            //YouVersionPlatformConfiguration.setAccessToken(result.accessToken)
            let result = SignInWithYouVersionResult(accessToken: "", refreshToken: "", permissions: [], yvpUserId: "")
            continuation.resume(returning: result)
        } catch {
            continuation.resume(throwing: error)
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
