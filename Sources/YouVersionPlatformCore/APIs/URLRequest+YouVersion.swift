import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension URLRequest {
    
    /// Creates a URLRequest with standard headers for YouVersion API calls.
    /// - Parameter url: The URL for the request.
    /// - Returns: A URLRequest with standard headers set.
    static func youVersion(
        _ url: URL,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: cachePolicy)
        if let appKey = YouVersionPlatformConfiguration.appKey {
            request.setValue(appKey, forHTTPHeaderField: "x-yvp-app-key")
        }
        if let installId = YouVersionPlatformConfiguration.installId {
            request.setValue(installId, forHTTPHeaderField: "x-yvp-installation-id")
        }
        if let accessToken = YouVersionPlatformConfiguration.accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "X-YV-LAT")
        }
        return request
    }
}
