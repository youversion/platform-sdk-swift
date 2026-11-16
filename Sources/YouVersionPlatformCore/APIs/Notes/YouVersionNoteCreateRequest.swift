import Foundation

/// A beta note creation request. Reuse this value when retrying a create to preserve idempotency.
public struct YouVersionNoteCreateRequest: Encodable, Sendable {
    public let requestID: UUID
    public let content: String
    public let status: YouVersionNote.Status
    public let title: String?
    public let color: String?
    /// Attached verses in one Bible version, book, and chapter; nil creates an unattached note.
    /// Empty or invalid selections throw when the request is encoded.
    public let references: [BibleReference]?
    public let languageTag: String?
    public let tags: [String]?

    /// Creates a request with a stable idempotency UUID.
    ///
    /// Content may be empty to save a passage without text. Color must be six lowercase hex digits. Language tags must use
    /// two lowercase letters, optionally followed by a region such as `en-US`.
    /// Tags must be nonempty and contain no commas. Nil optional fields have no value on creation.
    public init(
        content: String,
        status: YouVersionNote.Status,
        requestID: UUID = UUID(),
        title: String? = nil,
        color: String? = nil,
        references: [BibleReference]? = nil,
        languageTag: String? = nil,
        tags: [String]? = nil
    ) {
        self.requestID = requestID
        self.content = content
        self.status = status
        self.title = title
        self.color = color
        self.references = references
        self.languageTag = languageTag
        self.tags = tags
    }

    /// Encodes references as the API's nested passage object, validating the selection.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestID, forKey: .requestID)
        try container.encode(content, forKey: .content)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(color, forKey: .color)
        if let references {
            try container.encode(NotePassage(references: references), forKey: .references)
        }
        try container.encodeIfPresent(languageTag, forKey: .languageTag)
        try container.encodeIfPresent(tags, forKey: .tags)
    }

    private enum CodingKeys: String, CodingKey {
        case content, status, title, color, tags
        case references = "passage"
        case requestID = "request_id"
        case languageTag = "language_tag"
    }
}
