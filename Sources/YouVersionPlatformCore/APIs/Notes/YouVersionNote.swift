import Foundation

/// A user's note returned by the beta Notes API.
public struct YouVersionNote: Codable, Equatable, Identifiable, Sendable {
    /// Note visibility. The beta API supports private and public notes.
    public struct Status: RawRepresentable, Codable, Equatable, Sendable {
        public static let `private` = Self(rawValue: "private")
        public static let `public` = Self(rawValue: "public")

        public let rawValue: String

        /// Creates a status from its API value, preserving unknown response values.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Decodes a status from a JSON string.
        public init(from decoder: any Decoder) throws {
            rawValue = try decoder.singleValueContainer().decode(String.self)
        }

        /// Encodes the status as a JSON string.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    public let id: String
    public let title: String?
    public let content: String
    /// Six lowercase hexadecimal digits, without a leading hash.
    public let color: String?
    /// Attached references, or nil when the attachment is absent, null, or malformed.
    public let references: [BibleReference]?
    public let languageTag: String?
    public let tags: [String]?
    public let status: Status
    /// The creation timestamp as an ISO 8601 string, when supplied by the server.
    public let createdTime: String?
    /// The last update timestamp as an ISO 8601 string; nil if never updated or omitted.
    public let updatedTime: String?

    /// Decodes a note, retaining its content and metadata even when its attachment is malformed.
    /// An absent, null, or malformed attachment has `references == nil`; other malformed note fields still throw.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        do {
            references = try container.decodeIfPresent(NotePassage.self, forKey: .references)?.references
        } catch {
            references = nil
            YouVersionPlatformLogger.debug("Ignoring a malformed Notes attachment", category: "Notes")
        }
        languageTag = try container.decodeIfPresent(String.self, forKey: .languageTag)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        status = try container.decode(Status.self, forKey: .status)
        createdTime = try container.decodeIfPresent(String.self, forKey: .createdTime)
        updatedTime = try container.decodeIfPresent(String.self, forKey: .updatedTime)
    }

    /// Encodes a note using the API's nested passage object for its references.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(color, forKey: .color)
        if let references {
            try container.encode(NotePassage(references: references), forKey: .references)
        }
        try container.encodeIfPresent(languageTag, forKey: .languageTag)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(createdTime, forKey: .createdTime)
        try container.encodeIfPresent(updatedTime, forKey: .updatedTime)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, content, color, tags, status
        case references = "passage"
        case languageTag = "language_tag"
        case createdTime = "created_dt"
        case updatedTime = "updated_dt"
    }
}

/// One page of notes, newest first. The API does not return a total count.
public struct YouVersionNoteCollection: Codable, Equatable, Sendable {
    public let notes: [YouVersionNote]
    /// Pass this opaque token unchanged to the next collection request.
    public let nextPageToken: String?

    private enum CodingKeys: String, CodingKey {
        case notes = "data"
        case nextPageToken = "next_page_token"
    }
}
