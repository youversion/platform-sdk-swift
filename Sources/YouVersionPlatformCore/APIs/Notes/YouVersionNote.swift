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

    /// The verses attached to a note in one Bible, book, and chapter.
    /// Nonconsecutive selections use one `passage_id` string joined with `+`, such as
    /// `GEN.1.1+GEN.1.3+GEN.1.5`.
    public struct Passage: Codable, Equatable, Sendable {
        public let bibleID: Int
        public let passageID: String

        /// Creates a passage attachment, for example Bible 3034 and `JHN.3.16-18`.
        public init(bibleID: Int, passageID: String) {
            self.bibleID = bibleID
            self.passageID = passageID
        }

        /// Creates an attachment from selected verses or verse ranges in one Bible and chapter.
        /// Sorts and merges adjacent or overlapping ranges without filling gaps, and encodes ranges
        /// in the API's compact form (`GEN.1.1-3`). Returns nil for an empty selection, chapter-only
        /// references, invalid references, or selections spanning Bibles, books, or chapters.
        public init?(references: [BibleReference]) {
            guard let first = references.first,
                  first.chapter > 0,
                  first.bookId.wholeMatch(of: /[A-Z0-9]{3}/) != nil else {
                return nil
            }
            guard references.allSatisfy({ reference in
                guard let start = reference.verseStart, let end = reference.verseEnd else {
                    return false
                }
                return reference.versionId == first.versionId && reference.bookId == first.bookId &&
                    reference.chapter == first.chapter && start > 0 && end >= start && end < Int.max
            }) else {
                return nil
            }
            let passageIDs = BibleReference.referencesByMerging(references: references).map { reference in
                let start = reference.verseStart!
                let end = reference.verseEnd!
                let verseID = "\(reference.chapterPassageId).\(start)"
                return start == end ? verseID : "\(verseID)-\(end)"
            }
            self.init(bibleID: first.versionId, passageID: passageIDs.joined(separator: "+"))
        }

        /// The verse or range references represented by the API string, using this attachment's Bible.
        /// Returns nil for malformed or unsupported strings, including cross-chapter selections.
        /// Conversion is all-or-nothing; an invalid component never produces a partial selection.
        public var references: [BibleReference]? {
            let passageIDs = passageID.components(separatedBy: "+")
            let references = passageIDs.compactMap { value -> BibleReference? in
                guard value.wholeMatch(of: /[A-Z0-9]{3}\.[1-9][0-9]*\.[1-9][0-9]*(?:-[1-9][0-9]*)?/) != nil else {
                    return nil
                }
                return BibleReference.unvalidatedReference(with: value, versionId: bibleID)
            }
            guard references.count == passageIDs.count && Self(references: references) != nil else {
                return nil
            }
            return references
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
