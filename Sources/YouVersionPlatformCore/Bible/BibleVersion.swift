import Foundation

public struct BibleVersion: Codable, Sendable, Hashable, Equatable {
    public let id: Int
    public let abbreviation: String?
    public let promotionalContent: String?
    public let copyright: String?
    public let languageTag: String?  // see BCP 47
    public let localizedAbbreviation: String?
    public let localizedTitle: String?
    public let readerFooter: String?
    public let readerFooterUrl: String?
    public let title: String?
    public let organizationId: String?

    public let bookCodes: [String]?
    public let books: [BibleBook]?
    public let textDirection: String?

    // TEMPORARY:
    public let requiresEmailAgreement = false

    enum CodingKeys: String, CodingKey {
        case id
        case abbreviation
        case promotionalContent = "promotional_content"
        case copyright = "copyright"
        case languageTag = "language_tag"
        case localizedAbbreviation = "localized_abbreviation"
        case localizedTitle = "localized_title"
        case readerFooter = "info"
        case readerFooterUrl = "publisher_url"
        case title
        case bookCodes = "books"
        case books = "BibleBooks"  // not expected to be received
        case textDirection = "text_direction"
        case organizationId = "organization_id"
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
        return books.first { $0.id == usfm }
    }

    private func isBookUSFMValid(_ usfm: String) -> Bool {
        guard let books else {
            return false
        }
        let usfmUpper = usfm.uppercased()
        return books.contains(where: { $0.id == usfmUpper }) == true
    }

    public var bookUSFMs: [String] {
        if let bookCodes, !bookCodes.isEmpty {
            return bookCodes
        }
        guard let books else {
            return []
        }
        return books.compactMap { $0.id }
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
        guard let book = book(with: bookUSFM), let chapters = book.chapters else {
            return []
        }
        return chapters.compactMap { $0.title }
    }

    public static var preview: BibleVersion {
        // Create a minimal BibleVersion for preview purposes
        let promotionalContent = "This is minimal preview data for the Berean Standard Bible"
        return BibleVersion(
            id: 3034,
            abbreviation: "BSB",
            promotionalContent: promotionalContent,
            copyright: nil,
            languageTag: "en",
            localizedAbbreviation: "BSB",
            localizedTitle: "Berean Standard Bible",
            readerFooter: "Text is from the Berean Standard Bible",
            readerFooterUrl: "https://berean.bible",
            title: "Berean Standard Bible",
            organizationId: "1234-abcd-4321-fedc-0123456789ab",
            bookCodes: nil,
            books: nil,
            textDirection: "ltr"
        )
    }
}
