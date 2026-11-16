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

    /// A nonempty selection of verses in one Bible version, book, and chapter.
    /// References are normalized without filling gaps. API identifiers are converted only during coding.
    public struct Passage: Codable, Equatable, Sendable {
        public let references: [BibleReference]

        /// Creates an attachment, merging adjacent or overlapping ranges without filling gaps.
        /// Returns nil for empty, invalid, chapter-only, or mixed-version/book/chapter selections.
        public init?(references: [BibleReference]) {
            guard let references = Self.normalizedReferences(references, allowsChapter: false) else {
                return nil
            }
            self.references = references
        }

        /// Decodes the API's Bible ID and compact passage string into references.
        /// Malformed attachments throw; `YouVersionNote` tolerates those errors without losing the note.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let bibleID = try container.decode(Int.self, forKey: .bibleID)
            let passageID = try container.decode(String.self, forKey: .passageID)
            let components = passageID.components(separatedBy: "+")
            let references = components.compactMap { value -> BibleReference? in
                guard value.wholeMatch(of: /[A-Z0-9]{3}\.[1-9][0-9]*\.[1-9][0-9]*(?:-[1-9][0-9]*)?/) != nil else {
                    return nil
                }
                return BibleReference.unvalidatedReference(with: value, versionId: bibleID)
            }
            guard references.count == components.count, let passage = Self(references: references) else {
                throw DecodingError.dataCorruptedError(forKey: .passageID, in: container, debugDescription: "Invalid Notes passage selection")
            }
            self = passage
        }

        /// Encodes references using the API's compact ranges and `+` separator.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(references[0].versionId, forKey: .bibleID)
            try container.encode(Self.compactPassageID(for: references), forKey: .passageID)
        }

        /// Formats a validated chapter or same-chapter verse selection for a list query.
        static func queryPassageID(for references: [BibleReference]) -> String? {
            guard let references = normalizedReferences(references, allowsChapter: true) else {
                return nil
            }
            return compactPassageID(for: references)
        }

        private static func normalizedReferences(_ references: [BibleReference], allowsChapter: Bool) -> [BibleReference]? {
            guard let first = references.first, first.chapter > 0 && first.bookId.wholeMatch(of: /[A-Z0-9]{3}/) != nil else {
                return nil
            }
            guard references.allSatisfy({ reference in
                guard reference.versionId == first.versionId && reference.bookId == first.bookId && reference.chapter == first.chapter else {
                    return false
                }
                if reference.verseStart == nil && reference.verseEnd == nil {
                    return allowsChapter
                }
                guard let start = reference.verseStart, let end = reference.verseEnd else {
                    return false
                }
                return start > 0 && end >= start && end < Int.max
            }) else {
                return nil
            }
            if references.contains(where: { $0.verseStart == nil }) {
                return [first.chapterReference]
            }
            return BibleReference.referencesByMerging(references: references)
        }

        private static func compactPassageID(for references: [BibleReference]) -> String {
            references.map { reference in
                guard let start = reference.verseStart, let end = reference.verseEnd else {
                    return reference.chapterPassageId
                }
                let verseID = "\(reference.chapterPassageId).\(start)"
                return start == end ? verseID : "\(verseID)-\(end)"
            }.joined(separator: "+")
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
    /// Attached references, or nil when the attachment is absent, null, or malformed.
    public let passage: Passage?
    public let languageTag: String?
    public let tags: [String]?
    public let status: Status
    /// The creation timestamp as an ISO 8601 string, when supplied by the server.
    public let createdTime: String?
    /// The last update timestamp as an ISO 8601 string; nil if never updated or omitted.
    public let updatedTime: String?

    /// Decodes a note, retaining its content and metadata even when its attachment is malformed.
    /// An absent, null, or malformed attachment has `passage == nil`; other malformed note fields still throw.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        do {
            passage = try container.decodeIfPresent(Passage.self, forKey: .passage)
        } catch {
            passage = nil
            YouVersionPlatformLogger.debug("Ignoring a malformed Notes attachment", category: "Notes")
        }
        languageTag = try container.decodeIfPresent(String.self, forKey: .languageTag)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        status = try container.decode(Status.self, forKey: .status)
        createdTime = try container.decodeIfPresent(String.self, forKey: .createdTime)
        updatedTime = try container.decodeIfPresent(String.self, forKey: .updatedTime)
    }

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
