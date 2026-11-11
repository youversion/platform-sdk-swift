import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One page of full video resources and query metadata returned by video search.
public struct YouVersionVideoSearchResults: Sendable {
    public let videos: [YouVersionVideo]
    public let userIntent: YouVersionSearchUserIntent?
    public let didYouMean: [String]
    public let searchInsteadFor: String?
    /// Continue while this token is present, even when `videos` is empty.
    public let nextPageToken: String?
}

private struct VideoSearchResponse: Decodable {
    let videos: [YouVersionVideo]
    let userIntent: String?
    let didYouMean: [String]
    let searchInsteadFor: String?
    let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case videos
        case userIntent = "user_intent"
        case didYouMean = "did_you_mean"
        case searchInsteadFor = "search_instead_for"
        case nextPageToken = "next_page_token"
    }
}

public extension YouVersionAPI.Search {
    /// Returns one page of entitled videos matching `query`, with ready-to-use full-size thumbnail URLs.
    ///
    /// - Parameters:
    ///   - query: Search text containing 1 through 100 characters.
    ///   - organizationIDs: Publisher UUIDs to match with OR, or an empty array to search all accessible organizations.
    ///   - acceptLanguage: The HTTP language preference, such as `en-US,en;q=0.9`. Defaults to `en`, matching the API default.
    ///   - pageSize: A page size from 1 through 99. Omit for the server default, 25.
    ///   - pageToken: The previous page's continuation token. Keep query, organization filters, and language unchanged;
    ///     page size may change. Empty pages may still have a continuation token.
    ///   - accessToken: An optional access token; otherwise uses and refreshes the configured token.
    ///   - session: The URL session used to perform the request.
    /// - Throws: Invalid parameters, authentication, HTTP, network, or decoding errors. A returned thumbnail requires
    ///   a configured app key. Unauthorized requests throw `YouVersionAPIError.notPermitted`; other HTTP failures,
    ///   including invalid cursors and unavailable upstream catalogs, throw `YouVersionAPIError.cannotDownload`.
    static func videos(
        query: String,
        organizationIDs: [String] = [],
        acceptLanguage: String = "en",
        pageSize: Int? = nil,
        pageToken: String? = nil,
        accessToken providedToken: String? = nil,
        session: URLSession = .shared
    ) async throws -> YouVersionVideoSearchResults {
        guard (1...100).contains(query.count) && organizationIDs.allSatisfy({ UUID(uuidString: $0) != nil }) &&
              (pageSize.map { (1...99).contains($0) } ?? true) else {
            throw YouVersionAPIRequestError(code: .invalidParameter)
        }
        guard let url = URLBuilder.searchVideosURL(
            query: query, organizationIDs: organizationIDs, pageSize: pageSize, pageToken: pageToken
        ) else {
            throw URLError(.badURL)
        }
        let headers = ["Accept": "application/json", "Accept-Language": acceptLanguage]
        let data = try await YouVersionAPI.data(
            at: url, accessToken: await YouVersionAPI.accessToken(providedToken: providedToken, session: session),
            session: session, headers: headers
        )
        let response = try JSONDecoder().decode(VideoSearchResponse.self, from: data)
        return YouVersionVideoSearchResults(
            videos: try response.videos.map { try YouVersionAPI.Videos.resolvedVideo($0) },
            userIntent: response.userIntent.map { YouVersionSearchUserIntent(rawValue: $0) },
            didYouMean: response.didYouMean,
            searchInsteadFor: response.searchInsteadFor,
            nextPageToken: response.nextPageToken
        )
    }
}
