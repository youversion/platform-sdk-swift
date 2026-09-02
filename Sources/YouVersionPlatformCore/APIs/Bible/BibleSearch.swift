import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct YouVersionSearchUserIntent: RawRepresentable, Codable, Hashable, Sendable {
    public static let reference = Self(rawValue: "reference")
    public static let text = Self(rawValue: "text")
    public static let topical = Self(rawValue: "topical")
    public static let unknown = Self(rawValue: "unknown")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct YouVersionVerseSearchResult: Codable, Hashable, Sendable {
    public let reference: String

    public init(reference: String) {
        self.reference = reference
    }

    /// Converts the result's USFM reference to a Bible reference in `versionID`.
    public func bibleReference(versionID: Int) -> BibleReference? {
        let components = reference.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
              !components[0].isEmpty,
              let chapter = Int(components[1]),
              let verse = Int(components[2]),
              chapter > 0,
              verse > 0 else {
            return nil
        }
        return BibleReference(
            versionId: versionID,
            bookId: String(components[0]),
            chapter: chapter,
            verse: verse
        )
    }
}

public struct YouVersionVerseSearchResults: Codable, Hashable, Sendable {
    public let verses: [YouVersionVerseSearchResult]
    public let userIntent: YouVersionSearchUserIntent?
    public let didYouMean: [String]
    public let searchInsteadFor: String?
    public let nextPageToken: String?

    public init(
        verses: [YouVersionVerseSearchResult],
        userIntent: YouVersionSearchUserIntent?,
        didYouMean: [String],
        searchInsteadFor: String?,
        nextPageToken: String?
    ) {
        self.verses = verses
        self.userIntent = userIntent
        self.didYouMean = didYouMean
        self.searchInsteadFor = searchInsteadFor
        self.nextPageToken = nextPageToken
    }

    enum CodingKeys: String, CodingKey {
        case verses
        case userIntent = "user_intent"
        case didYouMean = "did_you_mean"
        case searchInsteadFor = "search_instead_for"
        case nextPageToken = "next_page_token"
    }
}

/// A search string a user might run and the source that supplied it.
public struct YouVersionSearchQuery: Codable, Hashable, Sendable {
    public let text: String
    public let source: String?

    public init(text: String, source: String?) {
        self.text = text
        self.source = source
    }
}

/// A collection of suggested or trending search queries.
public struct YouVersionSearchQueries: Codable, Hashable, Sendable {
    public let queries: [YouVersionSearchQuery]

    public init(queries: [YouVersionSearchQuery]) {
        self.queries = queries
    }

    enum CodingKeys: String, CodingKey {
        case queries = "data"
    }
}

public extension YouVersionAPI {
    enum Search {}
}

public extension YouVersionAPI.Search {
    /// Returns as-you-type search query suggestions matching `query` in the first supported language range.
    static func suggestedQueries(
        matching query: String,
        languageRanges: [String],
        accessToken providedToken: String? = nil,
        session: URLSession = .shared
    ) async throws -> YouVersionSearchQueries {
        guard !query.isEmpty else {
            throw YouVersionAPIRequestError(code: .invalidParameter)
        }
        return try await queries(
            languageRanges: languageRanges,
            query: query,
            isTrending: false,
            accessToken: providedToken,
            session: session
        )
    }

    /// Returns recently popular search queries in the first supported language range.
    static func trendingQueries(
        languageRanges: [String],
        accessToken providedToken: String? = nil,
        session: URLSession = .shared
    ) async throws -> YouVersionSearchQueries {
        try await queries(
            languageRanges: languageRanges,
            query: nil,
            isTrending: true,
            accessToken: providedToken,
            session: session
        )
    }

    /// Returns Bible verse search results matching `query` in the requested Bible version.
    ///
    /// - Parameters:
    ///   - query: The search text. Must contain between 1 and 100 characters.
    ///   - bibleID: The identifier of the Bible version to search.
    ///   - userIntent: The type of search the user intends to perform. Defaults to ``YouVersionSearchUserIntent/unknown``.
    ///   - pageSize: The maximum number of results to return. When supplied, must be between 1 and 99.
    ///   - pageToken: A continuation token returned by a previous search request.
    ///   - accessToken: An optional access token. Defaults to the configured access token.
    ///   - session: The URL session used to perform the request. Defaults to `URLSession.shared`.
    /// - Returns: The matching verse references and any continuation token supplied by the API.
    /// - Throws:
    ///   - `YouVersionAPIRequestError` with code `.invalidParameter` when `query`, `bibleID`, or `pageSize`
    ///     is outside the range accepted by the API.
    ///   - `URLError` if the request URL is invalid or the network request fails.
    ///   - `YouVersionAPIError.notPermitted` if the request is unauthorized or forbidden.
    ///   - `YouVersionAPIError.cannotDownload` if the server returns an unexpected status.
    ///   - `YouVersionAPIError.invalidResponse` if the server response is not HTTP.
    ///   - `DecodingError` if the response body is malformed.
    static func verses(
        query: String,
        bibleID: Int,
        userIntent: YouVersionSearchUserIntent = .unknown,
        pageSize: Int? = nil,
        pageToken: String? = nil,
        accessToken providedToken: String? = nil,
        session: URLSession = .shared
    ) async throws -> YouVersionVerseSearchResults {
        guard (1...100).contains(query.count),
              bibleID > 0,
              Int32(exactly: bibleID) != nil,
              pageSize.map({ (1...99).contains($0) }) ?? true else {
            throw YouVersionAPIRequestError(code: .invalidParameter)
        }

        guard let url = URLBuilder.searchVersesURL(
            query: query,
            bibleID: bibleID,
            userIntent: userIntent,
            pageSize: pageSize,
            pageToken: pageToken
        ) else {
            throw URLError(.badURL)
        }

        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken
        let data = try await YouVersionAPI.data(at: url, accessToken: accessToken, session: session)
        return try JSONDecoder().decode(YouVersionVerseSearchResults.self, from: data)
    }

    private static func queries(
        languageRanges: [String],
        query: String?,
        isTrending: Bool,
        accessToken providedToken: String?,
        session: URLSession
    ) async throws -> YouVersionSearchQueries {
        guard !languageRanges.isEmpty,
              languageRanges.allSatisfy({ !$0.isEmpty }) else {
            throw YouVersionAPIRequestError(code: .invalidParameter)
        }
        guard let url = URLBuilder.searchQueriesURL(
            languageRanges: languageRanges,
            query: query,
            isTrending: isTrending
        ) else {
            throw URLError(.badURL)
        }

        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken
        guard let data = try await YouVersionAPI.dataIfPresent(
            at: url,
            accessToken: accessToken,
            session: session
        ) else {
            return YouVersionSearchQueries(queries: [])
        }
        return try JSONDecoder().decode(YouVersionSearchQueries.self, from: data)
    }
}
