import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI.Bible {
    /// Retrieves a list of Bible versions available for a specified language code.
    ///
    /// This function fetches Bible version overviews for the provided three-letter language code (e.g., "eng").
    /// A valid `YouVersionPlatformConfiguration.appKey` must be set for the request to succeed.
    ///
    /// - Parameters:
    ///   - languageTag: An optional language code per BCP 47 for filtering available Bible versions. If `nil`
    ///     the function returns versions for all languages.
    ///   - session: The URLSession used to perform the request. Defaults to `URLSession.shared`.
    /// - Returns: An array of ``BibleVersion`` objects representing the available Bible versions for the language.
    ///
    /// - Throws:
    ///   - `URLError` if the URL is invalid.
    ///   - `YouVersionAPIError.notPermitted` if the app key is invalid or lacks permission.
    ///   - `YouVersionAPIError.cannotDownload` if the server returns an error response.
    ///   - `YouVersionAPIError.invalidResponse` if the server response is not valid.
    static func versions(forLanguageTag languageTag: String? = nil, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> [BibleVersion] {
        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken
        let range = languageTag == nil ? [] : [languageTag!]

        var allResults: [BibleVersion] = []
        var pageToken: String?

        repeat {
            guard let url = URLBuilder.versionsURL(languageRanges: range, pageSize: 99, pageToken: pageToken) else {
                throw URLError(.badURL)
            }

            let request = YouVersionAPI.buildRequest(url: url, accessToken: accessToken, session: session)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("unexpected response type")
                throw YouVersionAPIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                print("error 401: unauthorized. Check your appKey")
                throw YouVersionAPIError.notPermitted
            }

            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                print("error in findVersions: \(httpResponse.statusCode)")
                throw YouVersionAPIError.cannotDownload
            }

            if httpResponse.statusCode == 204 {
                pageToken = nil
            } else {
                let responseObject = try JSONDecoder().decode(BibleVersionsResponse.self, from: data)
                allResults.append(contentsOf: responseObject.data)
                pageToken = responseObject.next_page_token
                if responseObject.data.isEmpty {
                    pageToken = nil
                }
            }
        } while pageToken != nil

        return allResults
    }

    struct BibleVersionMinimalInfo: Equatable, Sendable {
        public let id: Int
        public let languageTag: String?  // see BCP 47
    }

    static func permittedVersions(
        forLanguageTag languageTag: String? = nil,
        accessToken providedToken: String? = nil,
        session: URLSession = .shared
    ) async throws -> [BibleVersionMinimalInfo] {
        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken
        let range = languageTag == nil ? [] : [languageTag!]

        let data = try await YouVersionAPI.commonFetch(
            // pageSize: nil means fetch them all. Permitted since we're only getting two fields.
            url: URLBuilder.versionsURL(languageRanges: range, fields: ["id", "language_tag"], pageSize: nil),
            accessToken: accessToken,
            session: session
        )
        let responseObject = try JSONDecoder().decode(BibleVersionsResponse.self, from: data)
        return responseObject.data.map({ BibleVersionMinimalInfo(id: $0.id, languageTag: $0.languageTag) })
    }

    private struct BibleVersionsResponse: Decodable {
        let data: [BibleVersion]
        let next_page_token: String?
        let total_size: Int?
    }
}
