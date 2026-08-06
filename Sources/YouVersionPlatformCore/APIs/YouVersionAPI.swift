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
        try await responseData(at: url, accessToken: accessToken, session: session).value
    }

    static func responseData(
        at url: URL,
        accessToken: String?,
        session: URLSession
    ) async throws -> BibleContentResponse<Data> {
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
        return BibleContentResponse(
            value: data,
            expirationDate: httpResponse.cacheExpirationDate(),
            isCacheable: httpResponse.allowsCaching
        )
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

struct AccessTokenRefreshBackoff {
    private struct RefreshFailure {
        let accessToken: String
        let count: Int
        let refreshToken: String
        let retryInstant: ContinuousClock.Instant
    }

    private var refreshFailure: RefreshFailure?

    /// Returns whether the credentials can make a refresh attempt at the given instant.
    func shouldAttemptRefresh(
        accessToken: String,
        refreshToken: String,
        at currentInstant: ContinuousClock.Instant
    ) -> Bool {
        guard let refreshFailure else {
            return true
        }
        guard refreshFailure.accessToken == accessToken && refreshFailure.refreshToken == refreshToken else {
            return true
        }
        return currentInstant >= refreshFailure.retryInstant
    }

    /// Records a failed refresh attempt and advances the retry delay.
    mutating func recordFailure(
        accessToken: String,
        refreshToken: String,
        at currentInstant: ContinuousClock.Instant
    ) {
        let matchesPreviousCredentials = refreshFailure?.accessToken == accessToken
            && refreshFailure?.refreshToken == refreshToken
        let previousFailureCount = matchesPreviousCredentials ? refreshFailure?.count ?? 0 : 0
        let failureCount = previousFailureCount + 1
        let exponent = min(failureCount - 1, 6)
        let backoffSeconds = min(5 * (1 << exponent), 300)
        refreshFailure = RefreshFailure(
            accessToken: accessToken,
            count: failureCount,
            refreshToken: refreshToken,
            retryInstant: currentInstant.advanced(by: .seconds(backoffSeconds))
        )
    }

    /// Clears the refresh failure history.
    mutating func reset() {
        refreshFailure = nil
    }
}

private actor AccessTokenProvider {
    private let clock = ContinuousClock()
    private var refreshBackoff = AccessTokenRefreshBackoff()
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
        guard refreshBackoff.shouldAttemptRefresh(
            accessToken: accessToken,
            refreshToken: refreshToken,
            at: clock.now
        ) else {
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
        if refreshedAccessToken == nil {
            refreshBackoff.recordFailure(
                accessToken: accessToken,
                refreshToken: refreshToken,
                at: clock.now
            )
        } else {
            refreshBackoff.reset()
        }
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
