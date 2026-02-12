import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

public struct SignInWithYouVersionPKCEParameters: Sendable {
    public let codeVerifier: String
    public let codeChallenge: String
    public let state: String
    public let nonce: String

    public init(codeVerifier: String, codeChallenge: String, state: String, nonce: String) {
        self.codeVerifier = codeVerifier
        self.codeChallenge = codeChallenge
        self.state = state
        self.nonce = nonce
    }
}

public enum SignInWithYouVersionPKCEAuthorizationError: Error {
    case unableToConstructAuthorizeURL
}

public struct SignInWithYouVersionPKCEAuthorizationRequest: Sendable {
    public let url: URL
    public let parameters: SignInWithYouVersionPKCEParameters
}

public enum SignInWithYouVersionPKCEAuthorizationRequestBuilder {

    public static func make(
        appKey: String,
        permissions: Set<SignInWithYouVersionPermission>,
        redirectURL: URL
    ) throws -> SignInWithYouVersionPKCEAuthorizationRequest {
        let codeVerifier = try randomURLSafeString(byteCount: 32)
        let codeChallenge = codeChallenge(for: codeVerifier)
        let state = try randomURLSafeString(byteCount: 24)
        let nonce = try randomURLSafeString(byteCount: 24)

        let parameters = SignInWithYouVersionPKCEParameters(
            codeVerifier: codeVerifier,
            codeChallenge: codeChallenge,
            state: state,
            nonce: nonce
        )

        let url = try authorizeURL(
            appKey: appKey,
            permissions: permissions,
            redirectURL: redirectURL,
            parameters: parameters
        )

        return SignInWithYouVersionPKCEAuthorizationRequest(url: url, parameters: parameters)
    }

    private static func authorizeURL(
        appKey: String,
        permissions: Set<SignInWithYouVersionPermission>,
        redirectURL: URL,
        parameters: SignInWithYouVersionPKCEParameters
    ) throws -> URL {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: appKey),
            URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
            URLQueryItem(name: "nonce", value: parameters.nonce),
            URLQueryItem(name: "state", value: parameters.state),
            URLQueryItem(name: "code_challenge", value: parameters.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        if let installId = YouVersionPlatformConfiguration.installId {
            queryItems.append(URLQueryItem(name: "x-yvp-installation-id", value: installId))
        }
        if let scopeValue = scopeValue(permissions: permissions) {
            queryItems.append(URLQueryItem(name: "scope", value: scopeValue))
        }

        guard let url = URLBuilder.authorizeURL(queryItems: queryItems) else {
            throw SignInWithYouVersionPKCEAuthorizationError.unableToConstructAuthorizeURL
        }
        return url
    }

    public static func tokenURLRequest(
        code: String,
        codeVerifier: String,
        redirectUri: String
    ) throws -> URLRequest {
        guard let url = URLBuilder.authTokenURL else {
            throw SignInWithYouVersionPKCEAuthorizationError.unableToConstructAuthorizeURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let parameters: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "client_id": YouVersionPlatformConfiguration.appKey ?? "",
            "code_verifier": codeVerifier
        ]
        let bodyString = parameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                                   .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return request
    }

    private static func randomURLSafeString(byteCount: Int) throws -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<byteCount).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) }
        return base64URLEncodedString(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return base64URLEncodedString(Data(digest))
    }

    private static func base64URLEncodedString(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func scopeValue(
        permissions: Set<SignInWithYouVersionPermission>
    ) -> String? {
        let fullScopes = permissions.union(Set([SignInWithYouVersionPermission.openid]))
        return fullScopes.map(\.rawValue).sorted().joined(separator: " ")
    }
}
