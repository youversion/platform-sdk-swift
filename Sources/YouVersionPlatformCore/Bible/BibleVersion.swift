import Foundation

public struct BibleVersion: Codable, Sendable, Hashable, Equatable {
    public let id: Int
    public let abbreviation: String?
    public let copyrightLong: String?
    public let copyrightShort: String?
    public let languageTag: String?  // see BCP 47
    public let localizedAbbreviation: String?
    public let localizedTitle: String?
    public let readerFooter: String?
    public let readerFooterUrl: String?
    public let title: String?

    public let bookCodes: [String]?
    public let books: [BibleBook]?
    public let textDirection: String?

    // TEMPORARY:
    public let requiresEmailAgreement = false

    enum CodingKeys: String, CodingKey {
        case id
        case abbreviation
        case copyrightLong = "copyright_long"
        case copyrightShort = "copyright_short"
        case languageTag = "language_tag"
        case localizedAbbreviation = "local_abbreviation"
        case localizedTitle = "local_title"
        case readerFooter = "info"
        case readerFooterUrl = "publisher_url"
        case title
        case bookCodes = "books"
        case books = "BibleBooks"  // not expected to be received
        case textDirection = "text_direction"
    }

    public static func == (lhs: BibleVersion, rhs: BibleVersion) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var isRightToLeft: Bool {
        textDirection == "rtl"
    }

    public func book(with usfm: String) -> BibleBook? {
        guard let books else {
            return nil
        }
        return books.first { $0.usfm == usfm }
    }

    private func isBookUSFMValid(_ usfm: String) -> Bool {
        guard let books else {
            return false
        }
        let usfmUpper = usfm.uppercased()
        return books.contains(where: { $0.usfm == usfmUpper }) == true
    }

    public var bookUSFMs: [String] {
        guard let books else {
            return []
        }
        return books.compactMap { $0.usfm }
    }

    public func reference(with usfm: String) -> BibleReference? {
        let trimmedUSFM = usfm.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmedUSFM.count >= 3 else {
            return nil
        }

        let subUSFMs = trimmedUSFM.split(separator: "+")
        if subUSFMs.count > 1 {
            let references = subUSFMs.compactMap { reference(with: String($0)) }
            let merged = BibleReference.referencesByMerging(references: references)
            return merged.first
        }

        guard let reference = BibleReference.unvalidatedReference(with: trimmedUSFM, versionId: id),
              isBookUSFMValid(reference.bookUSFM) else {
            return nil
        }
        return reference
    }

    /// Returns an array of displayable labels for chapters.
    /// In standard English books, this'll be like ["1", "2"...] but other cases exist.
    /// If metadata hasn't yet been loaded, or if the book code is bad, this will return []
    public func chapterLabels(_ bookUSFM: String) -> [String] {
        guard let book = book(with: bookUSFM) else {
            return []
        }
        return book.chapters?.filter({ $0.isCanonical != false }).compactMap { $0.title } ?? []
    }

    /// If metadata hasn't yet been loaded, or if the book code is bad, this will return 0.
    public func canonicalChapters(_ bookUSFM: String) -> [BibleChapter] {
        guard let book = book(with: bookUSFM), let chapters = book.chapters else {
            return []
        }
        return chapters.filter { $0.isCanonical == true }
    }

    public static var preview: BibleVersion {
        // Create a minimal BibleVersion for preview purposes
        let copyrightLong = """
King James Version (KJV)

The King James Version (KJV) of the holy Bible was first printed in 1611, but the main edition used today is the 1769 version. The King James Version (KJV) is also known as the Authorized (or Authorised) Version (AV) because it was authorized to be read in churches. For over 300 years it was the main English translation used in the English speaking world, and is much admired and respected. About 400 words and phrases coined or popularised by the King James Version are part the English language today.
"""
        return BibleVersion(
            id: 1,
            abbreviation: "KJV",
            copyrightLong: copyrightLong,
            copyrightShort: nil,
            languageTag: "en",
            localizedAbbreviation: "KJV",
            localizedTitle: "King James Version",
            readerFooter: "Text is from the King James Version",
            readerFooterUrl: "https://www.biblesociety.org.uk",
            title: "King James Version",
            bookCodes: nil,
            books: nil,
            textDirection: "ltr"
        )
    }
}
