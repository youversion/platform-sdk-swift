import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    enum Users {

        public static func getSignInResult(
            from callbackURL: URL,
            state: String,
            codeVerifier: String,
            redirectUri: String
        ) async throws -> SignInWithYouVersionResult {
            let location = try await obtainLocation(from: callbackURL, state: state)
            let code = try obtainCode(from: location)
            let tokens = try await obtainTokens(from: code, codeVerifier: codeVerifier, redirectUri: redirectUri)
            return try extractSignInWithYouVersionResult(from: tokens)
        }

        // this checks that the state parameter matches, and then fetches /auth/callback with the same parameters
        private static func obtainLocation(from callbackURL: URL, state: String) async throws -> String {
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

        private static func obtainCode(from location: String) throws -> String {
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

        private static func obtainTokens(from code: String, codeVerifier: String, redirectUri: String) async throws -> TokenResponse {
            let request = try SignInWithYouVersionPKCEAuthorizationRequestBuilder.tokenURLRequest(
                code: code,
                codeVerifier: codeVerifier,
                redirectUri: redirectUri
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

        private static func extractSignInWithYouVersionResult(from tokens: TokenResponse) throws -> SignInWithYouVersionResult {
            let idClaims = try decodeJWT(tokens.idToken)
            let permissions = tokens.scope
                .split(separator: ",")
                .compactMap { SignInWithYouVersionPermission(rawValue: String($0)) }
            return SignInWithYouVersionResult(
                accessToken: tokens.accessToken,
                expiresIn: "60",  // TEMPORARY FOR DEBUGGING //expiresIn: tokens.expiresIn,
                refreshToken: tokens.refreshToken,
                idToken: tokens.idToken,
                permissions: permissions,
                yvpUserId: idClaims["sub"] as? String,
                name: idClaims["sub"] as? String,
                profilePicture: idClaims["profile_picture"] as? String,
                email: idClaims["email"] as? String,
            )
        }

        private static func decodeJWT(_ token: String) throws -> [String: Any] {
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

        private struct TokenResponse: Codable, Sendable, Equatable {
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

        // MARK: - Refresh Token


        public static func performRefresh(
            with refreshToken: String,
            idToken: String?,
            session: URLSession = .shared
        ) async throws -> SignInWithYouVersionResult {
            /*
             curl -i -v 'https://api.youversion.com/auth/token' \
             -X POST \
             -H "x-yvp-app-key: $YVP_APP_KEY" \
             -H "x-yvp-installation-id: $YVP_INSTALL_ID" \
             -H 'Content-Type: application/x-www-form-urlencoded' \
             -d 'grant_type=refresh_token' \
             -d "client_id=$YVP_APP_KEY" \
             -d 'refresh_token=asdfasdf'
             */

            guard let url = URLBuilder.authRefreshURL() else {
                throw URLError(.badURL)
            }
            guard let appKey = YouVersionPlatformConfiguration.appKey else {
                throw YouVersionAPIError.missingAuthentication
            }

            let parameters: [String: String] = [
                "grant_type": "refresh_token",
                "client_id": appKey,
                "refresh_token": refreshToken
            ]
            let bodyString = parameters.map {
                "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
                .joined(separator: "&")

            var request = YouVersionAPI.buildRequest(url: url, accessToken: nil, session: session)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyString.data(using: .utf8)

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            guard let decodedResponse = try? JSONDecoder().decode(RefreshResponse.self, from: data) else {
                throw URLError(.badServerResponse)
            }
            return SignInWithYouVersionResult(
                accessToken: decodedResponse.accessToken,
                expiresIn: "60",  // TEMPORARY FOR DEBUGGING //decodedResponse.expiresIn,
                refreshToken: decodedResponse.refreshToken,
                idToken: idToken,
                permissions: [],
                yvpUserId: nil
            )
        }

        private struct RefreshResponse: Codable {
            let accessToken: String
            let expiresIn: String
            let refreshToken: String
            let scope: String

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case expiresIn = "expires_in"
                case refreshToken = "refresh_token"
                case scope
            }
        }

        // MARK: - Sign Out

        @MainActor
        public static func signOut() {
            YouVersionPlatformConfiguration.clearAuthTokens()
        }

    }
}

private final class RedirectDisabler: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil // disable following redirects
    }
}
