import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum YouVersionAPI {
    public static var isSignedIn: Bool {
        YouVersionPlatformConfiguration.accessToken != nil
    }

    static func commonFetch(url: URL?, accessToken: String, session: URLSession) async throws -> Data {
        guard let url else {
            throw URLError(.badURL)
        }

        let request = buildRequest(url: url, accessToken: accessToken, session: session)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("YouVersionAPI: unexpected response type")
            throw BibleVersionAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            print("from server: \(httpResponse.statusCode)")
            throw BibleVersionAPIError.notPermitted
        }

        guard httpResponse.statusCode == 200 else {
            print("from server: \(httpResponse.statusCode)")
            throw BibleVersionAPIError.cannotDownload
        }
        return data
    }

    static func buildRequest(
        url: URL,
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
