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
            preconditionFailure("YouVersionPlatformConfiguration.appKey must be set")
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
                        performLoopTwo(callbackURL, authorizationRequest: authorizationRequest, continuation: continuation)
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
            let request = try makeLoopThreeUrl(location: location, authorizationRequest: authorizationRequest)

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

    static func getCodeFromLoopThreeUrl(location: String) -> String? {
        guard let locationUrl = URL(string: location),
            let locationComponents = URLComponents(url: locationUrl, resolvingAgainstBaseURL: false),
              let locationQueryItems = locationComponents.queryItems,
              //queryItems.first(where: { $0.name == "state" })?.value == state,
              let codeQueryItem = locationQueryItems.first(where: { $0.name == "code" })
        else {
            return nil
        }
        
        return codeQueryItem.value
    }

    static func makeLoopThreeUrl(
        location: String,
        authorizationRequest: SignInWithYouVersionPKCEAuthorizationRequest
    ) throws -> URLRequest {
        guard let code = getCodeFromLoopThreeUrl(location: location) else {
            throw URLError(.badServerResponse)
        }
        let url = URL(string: "https://api-staging.youversion.com/auth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let redirectURL = "youversionauth://callback"
        let parameters: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURL,
            "client_id": YouVersionPlatformConfiguration.appKey ?? "",
            "code_verifier": authorizationRequest.parameters.codeVerifier
        ]
        let bodyString = parameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                                   .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return request
    }
}

private final class RedirectDisabler: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        return nil // disable following redirects
    }
}

#endif
