import Foundation

/// YouVersion Image metadata.
public struct YouVersionImage: Codable, Equatable, Identifiable, Sendable {
    /// An opaque identifier, set by the YouVersion server.
    public let id: String
    /// The image URL, including any query parameters required to access it.
    public let url: URL
    /// The verse or verse range to which the image corresponds (e.g. JHN.3.16).
    public let passageID: String
    /// The credit line which may be displayed with the image.
    public let attribution: String
    /// The BCP 47 language tag of the art's text.
    public let languageTag: String
    /// The native image width in pixels.
    public let width: Int
    /// The native image height in pixels.
    public let height: Int
    /// Native width divided by height, rounded by the server to three decimal places.
    public let aspectRatio: Double

    /// Creates YouVersion Image metadata from the supplied values.
    ///
    /// - Parameters:
    ///   - id: An opaque image identifier.
    ///   - url: The image URL, including any query parameters required to access it.
    ///   - passageID: The verse or verse range to which the image corresponds (e.g. JHN.3.16).
    ///   - attribution: The credit line which can be displayed with the image.
    ///   - languageTag: The BCP 47 language tag of the image's text.
    ///   - width: The native image width in pixels.
    ///   - height: The native image height in pixels.
    ///   - aspectRatio: The native width divided by height, as returned by the API.
    public init(
        id: String,
        url: URL,
        passageID: String,
        attribution: String,
        languageTag: String,
        width: Int,
        height: Int,
        aspectRatio: Double
    ) {
        self.id = id
        self.url = url
        self.passageID = passageID
        self.attribution = attribution
        self.languageTag = languageTag
        self.width = width
        self.height = height
        self.aspectRatio = aspectRatio
    }

    private enum CodingKeys: String, CodingKey {
        case id, attribution, width, height
        case url = "image_url"
        case passageID = "passage_id"
        case languageTag = "language_tag"
        case aspectRatio = "aspect_ratio"
    }
}

/// One page of images and the server's pagination metadata.
public struct YouVersionImageCollection: Codable, Equatable, Sendable {
    public let images: [YouVersionImage]
    /// The total across every page, when known. Typically available only for passage-filtered requests.
    public let totalSize: Int?
    /// An opaque continuation token to pass unchanged to the next collection request.
    public let nextPageToken: String?

    private enum CodingKeys: String, CodingKey {
        case images = "data"
        case totalSize = "total_size"
        case nextPageToken = "next_page_token"
    }
}
