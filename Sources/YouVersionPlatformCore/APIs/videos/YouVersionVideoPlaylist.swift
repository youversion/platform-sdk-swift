import Foundation

/// An organization's ordered playlist.
public struct YouVersionVideoPlaylist: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let type: String
    public let total: Int
    /// Ordered video IDs in the playlist.
    public let videoIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case id, title, type, total
        case videoIDs = "videos"
    }
}

/// One page of organization playlists.
public struct YouVersionVideoPlaylistCollection: Codable, Equatable, Sendable {
    public let playlists: [YouVersionVideoPlaylist]
    public let nextPageToken: String?

    private enum CodingKeys: String, CodingKey {
        case playlists = "data"
        case nextPageToken = "next_page_token"
    }
}
