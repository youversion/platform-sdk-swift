import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    enum Users {

        @MainActor
        public static func signOut() {
            YouVersionPlatformConfiguration.setAccessToken(nil)
        }

        /// Retrieves user information for the authenticated user using the provided access token.
        ///
        /// This function fetches the user's profile information from the YouVersion API, decoding it into a ``YouVersionUserInfo`` model.
        /// If `"preview"` is provided as the access token, a preview user info object will be returned for development or testing purposes.
        ///
        /// - Parameter accessToken: The access token obtained from the login process, or `"preview"` for test data.
        ///
        /// - Returns: A ``YouVersionUserInfo`` object containing the user's profile information.
        ///
        /// - Throws: An error if the URL is invalid, the network request fails, or the response cannot be decoded.
        public static func userInfo(accessToken providedToken: String?, session: URLSession = .shared) async throws -> YouVersionUserInfo {
            guard let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken else {
                preconditionFailure("accessToken must be set")
            }
            
            if accessToken == "preview" {
                return YouVersionUserInfo.preview
            }
            
            let data = try await YouVersionAPI.commonFetch(
                url: URLBuilder.userURL(accessToken: accessToken),
                session: session
            )

            guard let decodedResponse = try? JSONDecoder().decode(YouVersionUserInfo.self, from: data) else {
                throw URLError(.badServerResponse)
            }
            return decodedResponse
        }
        
    }
}
