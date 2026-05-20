import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {

    /// Returns whether the user has granted a data exchange permission.
    static func hasPermission(_ permission: DataExchangePermission) -> Bool {
        YouVersionPlatformConfiguration.savedDataExchangePermissions.contains(permission)
    }

    enum DataExchange {

        /// Creates a short-lived token for the just-in-time data exchange browser flow.
        ///
        /// - Parameters:
        ///   - permissions: The permissions to request from the signed-in user.
        ///   - accessToken: An access token to use instead of the stored access token.
        ///   - session: The URL session used to perform the request.
        /// - Returns: A data exchange token response.
        /// - Throws:
        ///   - `YouVersionAPIError.missingAuthentication` when the access token or app key is missing.
        ///   - `YouVersionAPIError.notPermitted` when the server returns `401`.
        ///   - `YouVersionAPIError.cannotDownload` when the server returns an unexpected status.
        ///   - `YouVersionAPIError.invalidResponse` when the server response is not HTTP.
        public static func token(
            permissions: Set<DataExchangePermission>,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> DataExchangeToken {
            guard let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken else {
                throw YouVersionAPIError.missingAuthentication
            }
            guard let appKey = YouVersionPlatformConfiguration.appKey else {
                throw YouVersionAPIError.missingAuthentication
            }
            guard let url = URLBuilder.dataExchangeTokenURL(appKey: appKey) else {
                throw URLError(.badURL)
            }

            let requestBody = DataExchangeTokenCreate(permissions: permissions.map(\.rawValue))

            var request = YouVersionAPI.urlRequest(with: url, accessToken: accessToken, session: session)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw YouVersionAPIError.invalidResponse
            }
            if httpResponse.statusCode == 401 {
                throw YouVersionAPIError.notPermitted
            }
            guard httpResponse.statusCode == 201 else {
                throw YouVersionAPIError.cannotDownload
            }

            return try JSONDecoder().decode(DataExchangeToken.self, from: data)
        }
    }
}

public struct DataExchangeToken: Codable, Sendable, Equatable {
    public let token: String
}

private struct DataExchangeTokenCreate: Codable {
    let permissions: [String]
}
