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
    public let thumbnail: Thumbnail?
    public let playbackSources: [PlaybackSource]
    public let playbackPreviewSources: [PlaybackSource]
    public let shareURL: URL?

    /// An image-proxy template and the source image's native dimensions.
    public struct Thumbnail: Codable, Equatable, Sendable {
        public let urlTemplate: String?
        public let width: Int?
        public let height: Int?

        public var aspectRatio: Double? {
            guard let width, let height, width > 0 && height > 0 else {
                return nil
            }
            return Double(width) / Double(height)
        }

        // TODO: When the API supplies a plain thumbnail URL, remove urlTemplate and the substitutions below;
        // update the model, callers, tests, and documentation to use that URL directly.
        /// Resolves the image-proxy placeholders to the requested pixel dimensions.
        public func url(width: Int, height: Int) -> URL? {
            guard let urlTemplate, width > 0 && height > 0 else {
                return nil
            }
            return URL(string: urlTemplate
                .replacingOccurrences(of: "{width}", with: String(width))
                .replacingOccurrences(of: "{height}", with: String(height)))
        }

        private enum CodingKeys: String, CodingKey {
            case urlTemplate = "url"
            case width, height
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
