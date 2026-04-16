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
            redirectUri: String,
            nonce: String,
            session: URLSession = .shared
        ) async throws -> SignInWithYouVersionResult {
            let location = try await obtainLocation(from: callbackURL, state: state, session: session)
            let code = try obtainCode(from: location)
            let tokens = try await obtainTokens(from: code, codeVerifier: codeVerifier, redirectUri: redirectUri, session: session)
            return try extractSignInWithYouVersionResult(from: tokens, nonce: nonce)
        }

        private static func applySessionHeaders(from session: URLSession, to request: inout URLRequest) {
            guard let additionalHeaders = session.configuration.httpAdditionalHeaders else {
                return
            }
            for (key, value) in additionalHeaders {
                guard let header = key as? String else { continue }
                if request.value(forHTTPHeaderField: header) == nil {
                    request.setValue("\(value)", forHTTPHeaderField: header)
                }
            }
        }

        // this checks that the state parameter matches, and then fetches /auth/callback with the same parameters
        static func obtainLocation(from callbackURL: URL, state: String, session: URLSession) async throws -> String {
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems,
                  queryItems.first(where: { $0.name == "state" })?.value == state,
                  let newURL = URLBuilder.authCallbackURL(queryItems: queryItems)
            else {
                throw URLError(.badURL)
            }

            final class RedirectDisabler: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
                func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                                newRequest request: URLRequest) async -> URLRequest? {
                    if response.url?.path() == "/auth/callback" {
                        return nil  // have it not follow the redirect
                    }
                    return request
                }
            }

            let redirectConfiguration = session.configuration
            let redirectSession = URLSession(configuration: redirectConfiguration, delegate: RedirectDisabler(), delegateQueue: nil)
            var request = URLRequest(url: newURL)
            request.httpMethod = "GET"
            applySessionHeaders(from: session, to: &request)

            let (_, response) = try await redirectSession.data(for: request)
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
                  let codeQueryItem = locationQueryItems.first(where: { $0.name == "code" }),
                  let code = codeQueryItem.value
            else {
                throw URLError(.badServerResponse)
            }
            return code
        }

        static func obtainTokens(from code: String, codeVerifier: String, redirectUri: String, session: URLSession) async throws -> TokenResponse {
            var request = try SignInWithYouVersionPKCEAuthorizationRequestBuilder.tokenURLRequest(
                code: code,
                codeVerifier: codeVerifier,
                redirectUri: redirectUri
            )
            applySessionHeaders(from: session, to: &request)

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            if httpResponse.statusCode != 200 {
                YouVersionPlatformLogger.error("obtainToken got status: \(httpResponse.statusCode)", category: "Auth")
                throw URLError(.badServerResponse)
            }

            return try JSONDecoder().decode(TokenResponse.self, from: data)
        }

        static func extractSignInWithYouVersionResult(from tokens: TokenResponse, nonce: String) throws -> SignInWithYouVersionResult {
            let idClaims = try decodeJWT(tokens.idToken)
            guard idClaims["nonce"] as? String == nonce else {
                YouVersionPlatformLogger.error("Nonce mismatch", category: "Auth")
                throw URLError(.badServerResponse)
            }
            let permissions = tokens.scope
                .split(separator: ",")
                .compactMap { SignInWithYouVersionPermission(rawValue: String($0)) }
            return SignInWithYouVersionResult(
                accessToken: tokens.accessToken,
                expiresIn: tokens.expiresIn,
                refreshToken: tokens.refreshToken,
                idToken: tokens.idToken,
                permissions: permissions,
                yvpUserId: idClaims["sub"] as? String,
                name: idClaims["name"] as? String,
                profilePicture: idClaims["profile_picture"] as? String,
                email: idClaims["email"] as? String,
            )
        }

        private static var currentIdClaims: [String: Any]? {
            guard let idToken = YouVersionPlatformConfiguration.authData?.idToken,
                  let idClaims = try? Self.decodeJWT(idToken) else {
                return nil
            }
            return idClaims
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

        private static func formURLEncoded(_ dict: [String: String]) -> Data? {
            var components = URLComponents()
            components.queryItems = dict.map { URLQueryItem(name: $0.key, value: $0.value) }
            return components.percentEncodedQuery?.data(using: .utf8)
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

        // MARK: - Refresh Token

        public static func performRefresh(
            with refreshToken: String,
            idToken: String?,
            session: URLSession = .shared
        ) async throws -> SignInWithYouVersionResult {
            guard let url = URLBuilder.authTokenURL else {
                throw URLError(.badURL)
            }
            guard let appKey = YouVersionPlatformConfiguration.appKey else {
                throw YouVersionAPIError.missingAuthentication
            }

            let bodyData = formURLEncoded([
                "grant_type": "refresh_token",
                "client_id": appKey,
                "refresh_token": refreshToken
            ])

            var request = YouVersionAPI.buildRequest(url: url, accessToken: nil, session: session)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
            applySessionHeaders(from: session, to: &request)

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
                expiresIn: decodedResponse.expiresIn,
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

        // MARK: - Public Accessors

        public static var currentUserId: String? {
            currentIdClaims?["sub"] as? String
        }

        public static var currentUserName: String? {
            currentIdClaims?["name"] as? String
        }

        public static var currentUserEmail: String? {
            currentIdClaims?["email"] as? String
        }

        public static var currentUserProfilePicture: String? {
            currentIdClaims?["profile_picture"] as? String
        }

        // MARK: - Sign Out

        @MainActor
        public static func signOut() {
            YouVersionPlatformConfiguration.clearAuthTokens()
        }

    }
}
