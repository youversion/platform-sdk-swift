import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum YouVersionAPI {

    /// This doesn't refresh the token when required, and therefore doesn't have to be async.
    public static var isSignedIn: Bool {
        YouVersionPlatformConfiguration.accessToken != nil
    }

    /// This can cause a token refresh if an access token is present but is old.
    public static func hasValidToken(session: URLSession = .shared) async -> Bool {
        guard let data = YouVersionPlatformConfiguration.authData,
              let expiry = data.expiryDate
        else {
            return false
        }
        guard expiry.timeIntervalSinceNow < 30 else {
            return true
        }
        guard let refreshToken = data.refreshToken,
              let result = try? await Users.refreshSignIn(withToken: refreshToken, idToken: data.idToken, session: session) else {
            YouVersionPlatformLogger.error("token refresh failed", category: "Auth")
            return false
        }
        await MainActor.run {
            YouVersionPlatformConfiguration.saveAuthData(
                accessToken: result.accessToken,
                refreshToken: result.refreshToken,
                idToken: result.idToken,
                expiryDate: result.expiryDate
            )
        }
        return true
    }

    static func data(at url: URL, accessToken: String?, session: URLSession) async throws -> Data {
        let request = urlRequest(with: url, accessToken: accessToken, session: session)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            YouVersionPlatformLogger.error("unexpected response type", category: "API")
            throw YouVersionAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            YouVersionPlatformLogger.error("from server: \(httpResponse.statusCode)", category: "API")
            throw YouVersionAPIError.notPermitted
        }

        guard httpResponse.statusCode == 200 else {
            YouVersionPlatformLogger.error("from server: \(httpResponse.statusCode)", category: "API")
            throw YouVersionAPIError.cannotDownload
        }
        return data
    }

    static func urlRequest(
        with url: URL,
        accessToken: String?,
        session: URLSession,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) -> URLRequest {
        var request = URLRequest.youVersion(url, accessToken: accessToken, cachePolicy: cachePolicy)

        if let additionalHeaders = session.configuration.httpAdditionalHeaders {
            for (key, value) in additionalHeaders {
                guard let headerField = key as? String else { continue }

                if request.value(forHTTPHeaderField: headerField) != nil {
                    continue
                }

                let headerValue: String
                switch value {
                case let str as String:
                    headerValue = str
                case let number as NSNumber:
                    headerValue = number.stringValue
                default:
                    headerValue = String(describing: value)
                }

                request.setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }

        return request
    }
}

public enum YouVersionAPIError: Error, Sendable {
    case missingAuthentication
    case notPermitted
    case cannotDownload
    case invalidDownload
    case invalidResponse
}
