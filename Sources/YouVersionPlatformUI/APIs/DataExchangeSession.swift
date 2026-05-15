#if canImport(AuthenticationServices)
import AuthenticationServices
import Foundation
import YouVersionPlatformCore

public enum DataExchangeRequestResult: String, Sendable {
    case granted
    case cancelled = "cancel"
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
    /// - Returns: A ``DataExchangeRequestResult`` describing whether the request was granted or cancelled.
    /// - Throws: An error if the token request fails, the browser session fails, or the callback status is invalid.
    @MainActor
    public func requestDataExchange(
        permissions: Set<SignInWithYouVersionPermission>
    ) async throws -> DataExchangeRequestResult {
        guard let appKey = YouVersionPlatformConfiguration.appKey else {
            throw YouVersionAPIError.missingAuthentication
        }

        let token = try await YouVersionAPI.DataExchange.token(permissions: permissions)
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

        if result == .granted {
            permissions.forEach(YouVersionPlatformConfiguration.saveDataExchangePermission)
        }

        return result
    }

    static func requestResult(from callbackURL: URL) throws -> DataExchangeRequestResult {
        guard
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let status = components.queryItems?.first(where: { $0.name == "status" })?.value,
            let result = DataExchangeRequestResult(rawValue: status)
        else {
            throw URLError(.badServerResponse)
        }

        return result
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
                do {
                    let result = try Self.requestResult(from: callbackURL)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            } else {
                continuation.resume(throwing: URLError(.badServerResponse))
            }
        }
    }

}

#endif
