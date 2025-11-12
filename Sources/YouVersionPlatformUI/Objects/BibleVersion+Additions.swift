import Foundation
import YouVersionPlatformCore

public extension BibleVersion {
    func bookName(_ bookUSFM: String) -> String? {
        guard let book = book(with: bookUSFM) else {
            return nil
        }
        return book.title ?? book.titleLong
    }
    // Example: "https://www.bible.com/bible/111/1SA.3.10.NIV"
    func shareUrl(reference: BibleReference) -> URL? {
        let prefix = "https://www.bible.com/bible/\(id)/"
        let book = reference.bookUSFM
        let version = (localizedAbbreviation?.isEmpty == false ? localizedAbbreviation : nil) ?? 
                     (abbreviation?.isEmpty == false ? abbreviation : nil) ?? 
                     String(id)
        
        let urlString = if let verseStart = reference.verseStart {
            if let verseEnd = reference.verseEnd, verseStart != verseEnd {
                "\(prefix)\(book).\(reference.chapter).\(verseStart)-\(verseEnd).\(version)"
            } else {
                "\(prefix)\(book).\(reference.chapter).\(verseStart).\(version)"
            }
        } else {
            "\(prefix)\(book).\(reference.chapter).\(version)"
        }

        return URL(string: urlString)
    }

    func displayTitle(for reference: BibleReference, includesVersionAbbreviation: Bool = true) -> String {
        var referenceOnlyChunks = titleChunks(for: reference)
        if isRightToLeft {
            referenceOnlyChunks.reverse()
        }
        let referenceOnlyTitle = referenceOnlyChunks.joined()
        var titleChunks = [referenceOnlyTitle]
        
        if includesVersionAbbreviation, let abbreviation = localizedAbbreviation ?? abbreviation {
            titleChunks.append(abbreviation)
            if isRightToLeft {
                titleChunks.reverse()
            }
        }
        return titleChunks.joined(separator: " ")
    }

    private func titleChunks(for reference: BibleReference) -> [String] {
        let bookUSFM = reference.bookUSFM
        let bookName = bookName(bookUSFM) ?? ""

        let hasOneChapter = canonicalChapters(bookUSFM).count == 1
        let chapterSeparator = hasOneChapter ? " " : ":"
        let bookAndChapterSeparator = hasOneChapter ? "" : " "
        let chapter = hasOneChapter ? "" : String(reference.chapter)

        switch (reference.verseStart, reference.verseEnd) {
        case (_, let verseEnd?) where verseEnd == 999:
            // Whole chapter
            return [bookName, bookAndChapterSeparator, chapter]
            
        case (nil, _):
            // Whole chapter
            return [bookName, bookAndChapterSeparator, chapter]
            
        case let (verseStart?, verseEnd?):
            if verseStart == verseEnd {
                // Single verse
                return [bookName, bookAndChapterSeparator, chapter, chapterSeparator, String(verseStart)]
            } else {
                // Verse range
                return [bookName, bookAndChapterSeparator, chapter, chapterSeparator, String(verseStart), "-", String(verseEnd)]
            }
            
        case let (verseStart?, nil):
            // Single verse with no verseEnd
            return [bookName, bookAndChapterSeparator, chapter, chapterSeparator, String(verseStart)]
        }
    }
}
