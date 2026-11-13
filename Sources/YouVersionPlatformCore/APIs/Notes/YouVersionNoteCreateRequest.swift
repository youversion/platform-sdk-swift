import Foundation

/// A beta note creation request. Reuse this value when retrying a create to preserve idempotency.
public struct YouVersionNoteCreateRequest: Encodable, Sendable {
    public let requestID: UUID
    public let content: String
    public let status: YouVersionNote.Status
    public let title: String?
    public let color: String?
    public let passage: YouVersionNote.Passage?
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
        passage: YouVersionNote.Passage? = nil,
        languageTag: String? = nil,
        tags: [String]? = nil
    ) {
        self.requestID = requestID
        self.content = content
        self.status = status
        self.title = title
        self.color = color
        self.passage = passage
        self.languageTag = languageTag
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case content, status, title, color, passage, tags
        case requestID = "request_id"
        case languageTag = "language_tag"
    }
}
