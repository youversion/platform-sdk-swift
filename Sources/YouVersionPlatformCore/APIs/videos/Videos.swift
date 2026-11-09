import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    /// Organization playlists and video metadata.
    struct Videos {
        private static let requestHeaders = ["Accept": "application/json"]

        private init() {}

        /// Returns one page of playlists, optionally limited to selected fields.
        /// Supported fields are `id`, `title`, `description`, `type`, `total`, and `videos`.
        /// Pass `nil` for `fields` to request all the fields. Omitted fields remain `nil`.
        /// Pass a numeric page size from `"1"` through `"99"`, or `"*"` with at most three fields
        /// to request all remaining playlists. A continuation token may be supplied with either form.
        /// Omit the page size to receive the server default. HTTP and decoding failures are thrown.
        public static func playlists(
            organizationID: String,
            fields: [String]? = nil,
            pageSize: String? = nil,
            pageToken: String? = nil,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionVideoPlaylistCollection {
            let allowedFields: Set<String> = ["id", "title", "description", "type", "total", "videos"]
            let isValidFields = fields.map { !$0.isEmpty && $0.allSatisfy(allowedFields.contains) } ?? true
            let isValidPageSize = pageSize.map { value in
                value == "*" ? (fields.map { !$0.isEmpty && $0.count <= 3 } ?? false)
                    : (Int(value).map { (1...99).contains($0) && String($0) == value } ?? false)
            } ?? true
            guard !organizationID.isEmpty && isValidFields && isValidPageSize else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            guard let url = URLBuilder.videoPlaylistsURL(
                organizationID: organizationID, fields: fields, pageSize: pageSize, pageToken: pageToken
            ) else {
                throw URLError(.badURL)
            }
            guard let data = try await YouVersionAPI.dataIfPresent(
                at: url, accessToken: await YouVersionAPI.accessToken(providedToken: providedToken, session: session), session: session,
                headers: requestHeaders
            ) else {
                return YouVersionVideoPlaylistCollection(playlists: [], nextPageToken: nil)
            }
            return try JSONDecoder().decode(YouVersionVideoPlaylistCollection.self, from: data)
        }

        /// Returns one playlist in its organization context.
        /// Uses the configured app key and optional access token.
        /// HTTP and decoding failures are thrown.
        public static func playlist(
            organizationID: String,
            id: Int,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionVideoPlaylist {
            guard !organizationID.isEmpty else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            guard let url = URLBuilder.videoPlaylistURL(organizationID: organizationID, id: id) else {
                throw URLError(.badURL)
            }
            let data = try await YouVersionAPI.data(
                at: url, accessToken: await YouVersionAPI.accessToken(providedToken: providedToken, session: session), session: session,
                headers: requestHeaders
            )
            return try JSONDecoder().decode(YouVersionVideoPlaylist.self, from: data)
        }

        // TODO: Remove the temporary English video-language override once the API video-language lookup issue is fixed.
        /// Resolves a video ID to metadata, thumbnail information, and playback URLs.
        /// The optional thumbnail size is `thumb`, `card`, or `full`; omit it for full size.
        /// Returned thumbnail URLs have sizing resolved and any required CDN app-key parameters added.
        /// A thumbnail requires a configured app key; otherwise `YouVersionAPIError.missingAuthentication` is thrown.
        /// An unknown ID (HTTP 404) throws `YouVersionAPIError.cannotDownload`.
        /// Uses the configured app key and optional access token.
        /// HTTP and decoding failures are thrown.
        public static func video(
            id: String,
            size: String? = nil,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionVideo {
            guard !id.isEmpty && (size.map { ["thumb", "card", "full"].contains($0) } ?? true) else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            guard let url = URLBuilder.videoURL(id: id) else {
                throw URLError(.badURL)
            }
            let data = try await YouVersionAPI.data(
                at: url, accessToken: await YouVersionAPI.accessToken(providedToken: providedToken, session: session), session: session,
                headers: ["Accept": "application/json", "Accept-Language": "en"]
            )
            var result = try JSONDecoder().decode(YouVersionVideo.self, from: data)
            guard let thumbnailURL = result.thumbnail?.url else {
                return result
            }
            guard let appKey = YouVersionPlatformConfiguration.appKey, !appKey.isEmpty else {
                throw YouVersionAPIError.missingAuthentication
            }
            guard let encodedAppKey = appKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
                  var components = URLComponents(url: thumbnailURL, resolvingAgainstBaseURL: false) else {
                throw URLError(.badURL)
            }
            // TODO this is temporary code: do not merge this to main.
            if components.path.contains("{width}") || components.path.contains("{height}") {
                let width = size == "thumb" ? 320 : size == "card" ? 1200 : 0
                components.path = components.path
                    .replacingOccurrences(of: "{width}", with: String(width))
                    .replacingOccurrences(of: "{height}", with: "0")
            } else {
                var queryItems = components.percentEncodedQueryItems?.filter { $0.name != "size" && $0.name != "app_key" } ?? []
                queryItems.append(URLQueryItem(name: "app_key", value: encodedAppKey))
                if let size {
                    queryItems.append(URLQueryItem(name: "size", value: size))
                }
                components.percentEncodedQueryItems = queryItems
            }
            guard let url = components.url else {
                throw URLError(.badURL)
            }
            result.thumbnail?.url = url
            return result
        }
    }
}
