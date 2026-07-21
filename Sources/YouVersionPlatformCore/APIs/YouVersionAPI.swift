import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum YouVersionAPI {

    private static let accessTokenProvider = AccessTokenProvider()

    /// This doesn't refresh the token when required, and therefore doesn't have to be async.
    public static var isSignedIn: Bool {
        YouVersionPlatformConfiguration.accessToken != nil
    }

    /// This can cause a token refresh if an access token is present but is old.
    public static func hasValidToken(session: URLSession = .shared) async -> Bool {
        await accessTokenProvider.accessToken(session: session) != nil
    }

    static func accessToken(providedToken: String?, session: URLSession) async -> String? {
        if let providedToken {
            return providedToken
        }
        return await accessTokenProvider.accessToken(session: session)
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
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        omitAccessToken: Bool = false
    ) -> URLRequest {
        var request = URLRequest.youVersion(url, accessToken: accessToken, cachePolicy: cachePolicy, omitAccessToken: omitAccessToken)

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

private actor AccessTokenProvider {
    private var refreshTask: Task<String?, Never>?

    func accessToken(session: URLSession) async -> String? {
        guard let authData = YouVersionPlatformConfiguration.authData,
              let accessToken = authData.accessToken else {
            return nil
        }
        guard let expiryDate = authData.expiryDate else {
            return accessToken
        }
        guard expiryDate.timeIntervalSinceNow < 30 else {
            return accessToken
        }
        if let refreshTask {
            return await refreshTask.value
        }
        guard let refreshToken = authData.refreshToken else {
            return nil
        }

        let task = Task {
            await Self.refreshAccessToken(
                refreshToken: refreshToken,
                idToken: authData.idToken,
                session: session
            )
        }
        refreshTask = task
        let refreshedAccessToken = await task.value
        refreshTask = nil
        return refreshedAccessToken
    }

    private static func refreshAccessToken(
        refreshToken: String,
        idToken: String?,
        session: URLSession
    ) async -> String? {
        guard let result = try? await YouVersionAPI.Users.refreshSignIn(
            withToken: refreshToken,
            idToken: idToken,
            session: session
        ) else {
            YouVersionPlatformLogger.error("token refresh failed", category: "Auth")
            return nil
        }
        await MainActor.run {
            YouVersionPlatformConfiguration.saveAuthData(
                accessToken: result.accessToken,
                refreshToken: result.refreshToken,
                idToken: result.idToken,
                expiryDate: result.expiryDate,
                permissions: result.permissionValues
            )
        }
        return result.accessToken
    }
}

public enum YouVersionAPIError: Error, Sendable {
    case missingAuthentication
    case notPermitted
    case cannotDownload
    case invalidDownload
    case invalidResponse
}
