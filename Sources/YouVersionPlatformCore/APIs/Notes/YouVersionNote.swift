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

    /// The single verse or contiguous verse range within one chapter attached to a note.
    public struct Passage: Codable, Equatable, Sendable {
        public let bibleID: Int
        public let passageID: String

        /// Creates a passage attachment, for example Bible 3034 and `JHN.3.16-18`.
        public init(bibleID: Int, passageID: String) {
            self.bibleID = bibleID
            self.passageID = passageID
        }

        private enum CodingKeys: String, CodingKey {
            case bibleID = "bible_id"
            case passageID = "passage_id"
        }
    }

    public let id: String
    public let title: String?
    public let content: String
    /// Six lowercase hexadecimal digits, without a leading hash.
    public let color: String?
    public let passage: Passage?
    public let languageTag: String?
    public let tags: [String]?
    public let status: Status
    /// The creation timestamp as an ISO 8601 string, when supplied by the server.
    public let createdTime: String?
    /// The last update timestamp as an ISO 8601 string; nil if never updated or omitted.
    public let updatedTime: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, content, color, passage, tags, status
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
