import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum YouVersionAPI {

    private static let accessTokenProvider = AccessTokenProvider()
    private static let httpDateFormatter: DateFormatter = {
        // swiftlint:disable:next ambiguous_dateformatter
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()

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

    static func dataIfPresent(at url: URL, accessToken: String?, session: URLSession) async throws -> Data? {
        try await response(
            at: url,
            accessToken: accessToken,
            session: session,
            allowsNoContent: true
        ).data
    }

    static func responseData(
        at url: URL,
        accessToken: String?,
        session: URLSession
    ) async throws -> BibleContentResponse<Data> {
        let response = try await response(
            at: url,
            accessToken: accessToken,
            session: session,
            allowsNoContent: false
        )
        guard let data = response.data else {
            throw YouVersionAPIError.cannotDownload
        }
        return BibleContentResponse(
            value: data,
            expirationDate: response.httpResponse.cacheExpirationDate(),
            isCacheable: response.httpResponse.allowsCaching
        )
    }

    private static func response(
        at url: URL,
        accessToken: String?,
        session: URLSession,
        allowsNoContent: Bool
    ) async throws -> (data: Data?, httpResponse: HTTPURLResponse) {
        let request = urlRequest(with: url, accessToken: accessToken, session: session)
        let (data, response) = try await YouVersionAPI.response(for: request, session: session)

        guard let httpResponse = response as? HTTPURLResponse else {
            YouVersionPlatformLogger.error("unexpected response type", category: "API")
            throw YouVersionAPIError.invalidResponse
        }

        if httpResponse.statusCode == 204 && allowsNoContent {
            return (nil, httpResponse)
        }

        guard httpResponse.statusCode == 200 else {
            YouVersionPlatformLogger.error("from server: \(httpResponse.statusCode)", category: "API")
            throw error(for: httpResponse, data: data)
        }
        return (data, httpResponse)
    }

    /// Returns the error that describes an unsuccessful HTTP response.
    ///
    /// - Parameters:
    ///   - httpResponse: The response whose status code and headers describe the failure.
    ///   - data: The response body, which can carry a message from the server.
    /// - Returns: `YouVersionAPIError.missingAuthentication` for `401`, `YouVersionAPIError.notPermitted` for `403`,
    ///   a ``YouVersionAPIResponseError`` for other `4xx` and `5xx` statuses, and
    ///   `YouVersionAPIError.cannotDownload` for any other status.
    static func error(for httpResponse: HTTPURLResponse, data: Data) -> any Error {
        let code: YouVersionAPIResponseError.Code
        switch httpResponse.statusCode {
        case 401:
            return YouVersionAPIError.missingAuthentication
        case 403:
            return YouVersionAPIError.notPermitted
        case 429:
            code = .rateLimited
        case 400..<500:
            code = .requestRejected
        case 500..<600:
            code = .serverError
        default:
            return YouVersionAPIError.cannotDownload
        }

        let body = ResponseErrorBody(data: data, contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"))
        if let message = body.message {
            YouVersionPlatformLogger.error("\(httpResponse.statusCode): \(message)", category: "API")
        }
        return YouVersionAPIResponseError(
            code: code,
            statusCode: httpResponse.statusCode,
            message: body.message,
            retryAfterSeconds: retryAfterSeconds(from: httpResponse.value(forHTTPHeaderField: "Retry-After")),
            validationIssues: body.validationIssues
        )
    }

    /// Returns the number of seconds a `Retry-After` header value asks the client to wait.
    ///
    /// - Parameters:
    ///   - value: The header value, either a number of seconds or an HTTP date.
    ///   - now: The date an HTTP date value is measured from.
    /// - Returns: The wait in seconds, never negative, or `nil` when the value is missing or malformed.
    static func retryAfterSeconds(from value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else {
            return nil
        }
        if let seconds = TimeInterval(value) {
            guard seconds.isFinite else {
                return nil
            }
            return max(0, seconds)
        }
        guard let date = httpDateFormatter.date(from: value) else {
            return nil
        }
        return max(0, date.timeIntervalSince(now))
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

/// An error the YouVersion Platform API returns for a request it did not complete.
///
/// Use ``code`` to decide how to recover. ``Code-swift.struct/rateLimited`` and
/// ``Code-swift.struct/serverError`` are temporary, so a later retry can succeed.
/// ``Code-swift.struct/requestRejected`` usually means the request itself is wrong, so retrying
/// it unchanged typically fails again.
public struct YouVersionAPIResponseError: Error, Sendable {
    /// The kind of failure the server reported.
    public struct Code: Equatable, Sendable {
        /// The app sent too many requests. Wait before retrying.
        public static let rateLimited = Self(rawValue: "rate_limited")
        /// The server failed to handle the request. A later retry can succeed.
        public static let serverError = Self(rawValue: "server_error")
        /// The server rejected the request, such as a resource that doesn't exist.
        /// Retrying unchanged usually fails again, though a few rejections, such as a request timeout, are temporary.
        public static let requestRejected = Self(rawValue: "request_rejected")

        /// A stable identifier for the failure kind.
        public let rawValue: String
    }

    /// A request parameter the server found invalid.
    public struct ValidationIssue: Equatable, Sendable {
        /// The path to the invalid value, such as `["query", "language_ranges"]`.
        public let location: [String]
        /// Why the value is invalid.
        public let message: String
    }

    /// The kind of failure the server reported.
    public let code: Code
    /// The HTTP status code of the response.
    public let statusCode: Int
    /// The server's description of the failure, when the response includes one.
    public let message: String?
    /// How many seconds the server asks the app to wait before retrying, from the `Retry-After` header.
    public let retryAfterSeconds: TimeInterval?
    /// The invalid request parameters, when the server reports them. Empty otherwise.
    public let validationIssues: [ValidationIssue]
}

/// The error body shapes the API returns: a `message`, a gateway `fault`, a validation `detail` list, or plain text.
struct ResponseErrorBody: Decodable {
    private struct Fault: Decodable {
        let faultString: String?

        private enum CodingKeys: String, CodingKey {
            case faultString = "faultstring"
        }
    }

    private struct Issue: Decodable {
        let location: [LocationComponent]?
        let message: String?

        private enum CodingKeys: String, CodingKey {
            case location = "loc"
            case message = "msg"
        }
    }

    private struct LocationComponent: Decodable {
        let value: String

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                value = string
            } else {
                value = String(try container.decode(Int.self))
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case message, fault, detail
    }

    private(set) var message: String?
    private(set) var validationIssues: [YouVersionAPIResponseError.ValidationIssue] = []

    /// Decodes an error body from a JSON `message`, a gateway `fault`, or a `detail` string or validation list.
    ///
    /// - Parameter decoder: The decoder to read from.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let issues = (try? container.decodeIfPresent([Issue].self, forKey: .detail)) ?? []
        validationIssues = issues.compactMap { issue in
            issue.message.map { YouVersionAPIResponseError.ValidationIssue(location: issue.location?.map(\.value) ?? [], message: $0) }
        }
        message = (try? container.decodeIfPresent(String.self, forKey: .message))
            ?? (try? container.decodeIfPresent(Fault.self, forKey: .fault))?.faultString
            ?? (try? container.decodeIfPresent(String.self, forKey: .detail))
            ?? validationIssues.first?.message
    }

    /// Parses an error response body, falling back to the raw text of a `text/plain` response.
    ///
    /// - Parameters:
    ///   - data: The response body.
    ///   - contentType: The response's `Content-Type` header value.
    init(data: Data, contentType: String?) {
        if let decoded = try? JSONDecoder().decode(Self.self, from: data) {
            self = decoded
        } else if contentType?.lowercased().hasPrefix("text/plain") == true,
                  let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty {
            message = text
        }
    }
}

public struct YouVersionAPIRequestError: Error, Sendable {
    public struct Code: Equatable, Sendable {
        public static let invalidParameter = Self(rawValue: "invalid_parameter")

        public let rawValue: String
    }

    public let code: Code
}
