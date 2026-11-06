import Foundation

/// Video metadata and entitled playback sources returned by the Videos API.
public struct YouVersionVideo: Codable, Equatable, Sendable {
    /// The video ID.
    public let id: String
    public let title: String?
    public let description: String?
    /// USFM expressions supplied by the API, including ranges and combined references.
    public let references: [String]?
    public let languageTag: String?
    public let runtime: Int?
    public let orientation: String?
    public internal(set) var thumbnail: Thumbnail?
    public let playbackSources: [PlaybackSource]
    public let playbackPreviewSources: [PlaybackSource]
    public let shareURL: URL?

    /// A thumbnail URL and the source image’s native dimensions.
    public struct Thumbnail: Codable, Equatable, Sendable {
        /// The thumbnail URL, ready to use after `YouVersionAPI.Videos.video` resolves sizing and required CDN parameters.
        public internal(set) var url: URL?
        public let width: Int?
        public let height: Int?

        public var aspectRatio: Double? {
            guard let width, let height, width > 0 && height > 0 else {
                return nil
            }
            return Double(width) / Double(height)
        }
    }

    /// A full-length or preview stream, with its server-provided format such as `hls`, `webm`, `mp4`, or `mp3`.
    public struct PlaybackSource: Codable, Equatable, Sendable {
        public let url: URL
        public let format: String
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, references, runtime, orientation, thumbnail
        case languageTag = "language_tag"
        case playbackSources = "playback_sources"
        case playbackPreviewSources = "playback_preview_sources"
        case shareURL = "share_url"
    }
}
