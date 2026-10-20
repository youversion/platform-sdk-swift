import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    /// Lists and resolves verse-art metadata from the Images API.
    struct Images {
        private init() {}

        /// Returns a page of images matching all supplied filters.
        ///
        /// Configure a valid app key before calling this API. This returns metadata rather than image bytes.
        /// - Parameters:
        ///   - passageID: A single verse or verse range, such as `JHN.3.16` or `1CO.13.4-7`.
        ///     Bare chapters are unsupported and rejected by the server. Omit to browse across passages.
        ///   - languageRanges: Ordered basic language ranges. Use `*` for all languages;
        ///     an empty array omits the language filter.
        ///   - pageSize: The number of results, from 1 through 99. Omit to use the server default of 25.
        ///   - pageToken: The opaque continuation token from a previous page.
        ///   - accessToken: An optional access token. Defaults to the configured access token.
        ///   - session: The URL session used to perform the request.
        /// - Returns: Full image records, an optional total, and an optional continuation token.
        ///   Filters matching nothing produce an empty `images` array.
        /// - Throws: `YouVersionAPIRequestError` with code `.invalidParameter` for invalid page sizes; `URLError` for URL or transport failures; `YouVersionAPIError` for HTTP failures;
        ///   or `DecodingError` for malformed metadata.
        public static func images(
            passageID: String? = nil,
            languageRanges: [String] = [],
            pageSize: Int? = nil,
            pageToken: String? = nil,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionImageCollection {
            guard pageSize.map({ (1...99).contains($0) }) ?? true else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            guard let url = URLBuilder.imagesURL(
                passageID: passageID,
                languageRanges: languageRanges,
                pageSize: pageSize,
                pageToken: pageToken
            ) else {
                throw URLError(.badURL)
            }
            let data = try await YouVersionAPI.data(
                at: url,
                accessToken: providedToken ?? YouVersionPlatformConfiguration.accessToken,
                session: session
            )
            return try JSONDecoder().decode(YouVersionImageCollection.self, from: data)
        }

        /// Resolves an opaque image identifier to its full metadata.
        ///
        /// - Parameters:
        ///   - id: The opaque image ID returned by the Images, search, or Verse of the Day APIs.
        ///   - accessToken: An optional access token. Defaults to the configured access token.
        ///   - session: The URL session used to perform the request.
        /// - Returns: Full metadata including the CDN URL, passage, attribution, language, and dimensions.
        /// - Throws: `YouVersionAPIRequestError` with code `.invalidParameter` for an empty identifier;
        ///   `URLError` for URL or transport failures; `YouVersionAPIError` for HTTP failures;
        ///   or `DecodingError` for malformed metadata.
        public static func image(
            id: String,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionImage {
            guard !id.isEmpty else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            guard let url = URLBuilder.imageURL(id: id) else {
                throw URLError(.badURL)
            }
            let data = try await YouVersionAPI.data(
                at: url,
                accessToken: providedToken ?? YouVersionPlatformConfiguration.accessToken,
                session: session
            )
            return try JSONDecoder().decode(YouVersionImage.self, from: data)
        }
    }
}
