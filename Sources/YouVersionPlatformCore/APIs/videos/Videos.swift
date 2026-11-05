import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    /// Organization playlists and video metadata.
    struct Videos {
        private static let requestHeaders = ["Accept": "application/json"]

        private init() {}

        /// Returns one page of playlists for an organization, or an empty page for HTTP 204.
        /// Pass a returned continuation token unchanged to retrieve the next page.
        /// An optional page size from 1 through 99 requests how many playlists to return; omit for the server default of 25.
        /// Uses the configured app key and optional access token.
        /// HTTP and decoding failures are thrown.
        public static func playlists(
            organizationID: String,
            pageSize: Int? = nil,
            pageToken: String? = nil,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionVideoPlaylistCollection {
            guard !organizationID.isEmpty && (pageSize.map { (1...99).contains($0) } ?? true) else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            guard let url = URLBuilder.videoPlaylistsURL(organizationID: organizationID, pageSize: pageSize, pageToken: pageToken) else {
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

        /// Resolves a video ID to metadata, thumbnail information, and playback URLs.
        /// An unknown ID (HTTP 404) throws `YouVersionAPIError.cannotDownload`.
        /// Uses the configured app key and optional access token.
        /// HTTP and decoding failures are thrown.
        public static func video(
            id: String,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionVideo {
            guard !id.isEmpty else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            guard let url = URLBuilder.videoURL(id: id) else {
                throw URLError(.badURL)
            }
            let data = try await YouVersionAPI.data(
                at: url, accessToken: await YouVersionAPI.accessToken(providedToken: providedToken, session: session), session: session,
                headers: requestHeaders
            )
            return try JSONDecoder().decode(YouVersionVideo.self, from: data)
        }
    }
}
