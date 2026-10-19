import Foundation

/// Full verse-art metadata. Image bytes are served separately by the Platform CDN.
public struct YouVersionImage: Codable, Equatable, Identifiable, Sendable {
    /// An opaque identifier; do not decode or construct it.
    public let id: String
    /// The CDN URL, including any query parameters required to access the image.
    public let imageURL: URL
    /// The illustrated passage, as a verse or verse range identifier.
    public let passageID: String
    /// The credit line to display with the image.
    public let attribution: String
    /// The BCP 47 language tag of the art's text.
    public let languageTag: String
    /// The native image width in pixels.
    public let width: Int
    /// The native image height in pixels.
    public let height: Int
    /// Native width divided by height, rounded by the server to three decimal places.
    public let aspectRatio: Double

    enum CodingKeys: String, CodingKey {
        case id, attribution, width, height
        case imageURL = "image_url"
        case passageID = "passage_id"
        case languageTag = "language_tag"
        case aspectRatio = "aspect_ratio"
    }
}

/// One page of verse-art images and the server's pagination metadata.
public struct YouVersionImageCollection: Codable, Equatable, Sendable {
    public let images: [YouVersionImage]
    /// The total across every page, when known. Typically available only for passage-filtered requests.
    public let totalSize: Int?
    /// An opaque continuation token to pass unchanged to the next collection request.
    public let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case images = "data"
        case totalSize = "total_size"
        case nextPageToken = "next_page_token"
    }
}
