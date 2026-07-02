#if canImport(AuthenticationServices)
import AuthenticationServices
import Foundation
import YouVersionPlatformCore

public struct DataExchangeRequestResult: Equatable, Sendable {
    public enum Status: RawRepresentable, Hashable, CustomStringConvertible, Sendable {
        case granted
        case cancel
        case missing
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "granted":
                self = .granted
            case "cancel":
                self = .cancel
            case "":
                self = .missing
            default:
                self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .granted:
                return "granted"
            case .cancel:
                return "cancel"
            case .missing:
                return ""
            case .unknown(let rawValue):
                return rawValue
            }
        }

        public var description: String { rawValue }
    }

    public let status: Status
    public let grantedPermissions: [SignInWithYouVersionPermission]

    public init(status: Status, grantedPermissions: [SignInWithYouVersionPermission]) {
        self.status = status
        self.grantedPermissions = grantedPermissions
    }

    public var isGranted: Bool {
        status == .granted
    }
}

public struct DataExchangeSession {

#if !os(tvOS)
    private let contextProvider: ASWebAuthenticationPresentationContextProviding

    public init(contextProvider: ASWebAuthenticationPresentationContextProviding) {
        self.contextProvider = contextProvider
    }
#else
    public init() {}
#endif

    /// Presents the YouVersion data exchange permission flow to the user and returns the selected result.
    ///
    /// - Parameter permissions: The set of permissions to request from the user.
    /// - Returns: A ``DataExchangeRequestResult`` containing the callback status and granted permission values.
    /// - Throws: An error if the token request or browser session fails.
    @MainActor
    public func requestDataExchange(
        permissions: Set<SignInWithYouVersionPermission>
    ) async throws -> DataExchangeRequestResult {
        guard let appKey = YouVersionPlatformConfiguration.appKey else {
            throw YouVersionAPIError.missingAuthentication
        }
        
        let token: DataExchangeToken
        do {
            token = try await YouVersionAPI.DataExchange.updateToken(withPermissions: permissions)
        } catch {
            YouVersionPlatformLogger.error("DataExchange.updateToken failed: \(error)", category: "DataExchange")
            throw URLError(.badServerResponse)
        }

        guard let url = URLBuilder.dataExchangeURL(token: token.token, appKey: appKey) else {
            throw URLError(.badURL)
        }

        let redirectURL = URL(string: "youversionauth://callback")!
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DataExchangeRequestResult, Error>) in
            let session = dataExchangeSession(url: url, redirectURL: redirectURL, continuation)
#if !os(tvOS)
            session.presentationContextProvider = contextProvider
#endif
            session.start()
        }

        if result.isGranted {
            YouVersionPlatformConfiguration.savePermissions(result.grantedPermissions)
        }

        return result
    }

    static func requestResult(from callbackURL: URL) -> DataExchangeRequestResult {
        let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return DataExchangeRequestResult(
            status: queryItems.first { $0.name == "data_exchange_status" }?.value
                .map { DataExchangeRequestResult.Status(rawValue: $0) } ?? .missing,
            grantedPermissions: queryItems
                .filter { $0.name == "granted_permissions" }
                .compactMap(\.value)
                .flatMap { permissions(from: $0) }
        )
    }

    private static func permissions(from value: String) -> [SignInWithYouVersionPermission] {
        value
            .split { $0 == "," || $0 == " " }
            .map { SignInWithYouVersionPermission(rawValue: String($0)) }
    }

    private func dataExchangeSession(
        url: URL,
        redirectURL: URL,
        _ continuation: CheckedContinuation<DataExchangeRequestResult, any Error>
    ) -> ASWebAuthenticationSession {
        ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: redirectURL.scheme!
        ) { callbackURL, error in
            if let error {
                continuation.resume(throwing: error)
            } else if let callbackURL {
                let result = Self.requestResult(from: callbackURL)
                continuation.resume(returning: result)
            } else {
                continuation.resume(throwing: URLError(.badServerResponse))
            }
        }
    }

}

#endif
