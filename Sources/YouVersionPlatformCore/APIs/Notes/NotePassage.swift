import Foundation

/// Internal conversion between Notes wire attachments and validated references.
struct NotePassage: Codable, Sendable {
    let references: [BibleReference]

    /// Creates an attachment, merging adjacent or overlapping ranges without filling gaps.
    /// Throws for empty, invalid, chapter-only, or mixed-version/book/chapter selections.
    init(references: [BibleReference]) throws {
        guard let references = normalizedNoteReferences(references) else {
            throw YouVersionAPIRequestError(code: .invalidParameter)
        }
        self.references = references
    }

    /// Decodes the API's Bible ID and compact passage string into references.
    /// Malformed attachments throw; `YouVersionNote` tolerates those errors without losing the note.
    init(from decoder: any Decoder) throws {
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
        guard references.count == components.count, let references = normalizedNoteReferences(references) else {
            throw DecodingError.dataCorruptedError(forKey: .passageID, in: container, debugDescription: "Invalid Notes passage selection")
        }
        self.references = references
    }

    /// Encodes references using the API's compact ranges and `+` separator.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(references[0].versionId, forKey: .bibleID)
        try container.encode(Self.compactPassageID(for: references), forKey: .passageID)
    }

    /// Formats a validated chapter or same-chapter verse selection for a list query.
    static func queryPassageID(for references: [BibleReference]) -> String? {
        guard let references = normalizedNoteReferences(references, allowsChapter: true) else {
            return nil
        }
        return compactPassageID(for: references)
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

/// Validates Notes selections for Core and Reader, normalizing ranges without filling gaps.
package func normalizedNoteReferences(_ references: [BibleReference], allowsChapter: Bool = false) -> [BibleReference]? {
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
