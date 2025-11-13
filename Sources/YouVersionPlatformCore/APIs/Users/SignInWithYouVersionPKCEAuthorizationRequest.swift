import CryptoKit
import Foundation
import Security

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
    case randomGenerationFailed
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
        var components = URLComponents()
        components.scheme = "https"
        components.host = YouVersionPlatformConfiguration.apiHost
        components.path = "/auth/authorize"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: appKey),
            URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
            URLQueryItem(name: "nonce", value: parameters.nonce),
            URLQueryItem(name: "state", value: parameters.state),
            URLQueryItem(name: "code_challenge", value: parameters.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        if let installId = YouVersionPlatformConfiguration.installId {
            queryItems.append(URLQueryItem(name: "x-yvp-installation-id", value: installId))
        }
        if let scopeValue = scopeValue(permissions: permissions) {
            queryItems.append(URLQueryItem(name: "scope", value: scopeValue))
        }

        components.queryItems = queryItems
        guard let url = components.url else {
            throw SignInWithYouVersionPKCEAuthorizationError.unableToConstructAuthorizeURL
        }

        return url
    }

    public static func tokenURLRequest(
        location: String,
        codeVerifier: String,
        redirectUri: String
    ) throws -> URLRequest {
        guard let locationUrl = URL(string: location),
              let locationComponents = URLComponents(url: locationUrl, resolvingAgainstBaseURL: false),
              let locationQueryItems = locationComponents.queryItems,
              //locationQueryItems.first(where: { $0.name == "state" })?.value == state,
              let codeQueryItem = locationQueryItems.first(where: { $0.name == "code" }),
              let code = codeQueryItem.value
        else {
            throw URLError(.badServerResponse)
        }

        let url = URL(string: "https://api-staging.youversion.com/auth/token")!
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
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else {
            throw SignInWithYouVersionPKCEAuthorizationError.randomGenerationFailed
        }
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
        var scopeWithOpenID = permissions.map(\.rawValue).sorted().joined(separator: " ")
        if !scopeWithOpenID.split(separator: " ").contains("openid") {
            scopeWithOpenID += (scopeWithOpenID.isEmpty ? "" : " ") + "openid"
        }
        return scopeWithOpenID
    }
}
