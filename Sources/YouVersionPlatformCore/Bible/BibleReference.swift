import Foundation

public struct BibleReference: Comparable, Codable, Hashable, Sendable, CustomDebugStringConvertible {
    public let versionId: Int
    public let bookUSFM: String
    public let chapter: Int
    public let verseStart: Int?
    public let verseEnd: Int?

    public init(versionId: Int, bookUSFM: String, chapter: Int, verse: Int? = nil) {
        assert(chapter >= 1, "Chapter must be greater than or equal to 1.")
        if let verse {
            assert(verse >= 1, "Verse must be greater than or equal to 1.")
        }
        
        self.versionId = versionId
        self.bookUSFM = bookUSFM
        self.chapter = chapter
        self.verseStart = verse
        self.verseEnd = verse
    }
    
    public init(versionId: Int, bookUSFM: String, chapter: Int, verseStart: Int, verseEnd: Int) {
        assert(chapter >= 1, "Starting chapter must be greater than or equal to 1.")
        assert(verseStart >= 1, "Starting verse must be greater than or equal to 1.")
        assert(verseEnd >= 1, "Ending verse must be greater than or equal to 1.")
        assert(verseEnd >= verseStart, "Ending verse must be equal to or after starting verse.")
        
        self.versionId = versionId
        self.bookUSFM = bookUSFM
        self.chapter = chapter
        self.verseStart = verseStart
        self.verseEnd = verseEnd
    }

    public var debugDescription: String {
        let prefix = "bible\(versionId)__\(bookUSFM).\(chapter)"
        if let verseStart {
            if let verseEnd, verseStart != verseEnd {
                return "\(prefix).\(verseStart)-\(verseEnd)"
            } else {
                return "\(prefix).\(verseStart)"
            }
        }
        return prefix
    }

    public var isRange: Bool {
        verseEnd != nil && verseStart != verseEnd
    }
    
    public static func compare(a: BibleReference, b: BibleReference) -> Int {
        // returns -1, 0, or 1
        if a.bookUSFM != b.bookUSFM {
            return a.bookUSFM < b.bookUSFM ? -1 : 1
        }
        
        if a.chapter != b.chapter {
            return a.chapter < b.chapter ? -1 : 1
        }
        
        switch (a.verseStart, b.verseStart) {
        case let (lhs?, rhs?):
            if lhs == rhs {
                return switch (a.verseEnd, b.verseEnd) {
                case let (lhs?, rhs?):
                    lhs == rhs ? 0 : (lhs < rhs ? -1 : 1)
                case (nil, nil):
                    0
                case (nil, _):
                    1
                case (_, nil):
                    -1
                }
            }
            return lhs < rhs ? -1 : 1
        case (nil, nil):
            return 0
        case (nil, _):
            return -1
        case (_, nil):
            return 1
        }
    }
    
    public static func < (lhs: BibleReference, rhs: BibleReference) -> Bool {
        compare(a: lhs, b: rhs) < 0
    }

    public var chapterUSFM: String? {
        "\(bookUSFM.uppercased()).\(chapter)"
    }

    public var asUSFM: String {
        let upperBookUSFM = bookUSFM.uppercased()
        if let verseStart {
            if let verseEnd, verseStart != verseEnd {
                return "\(upperBookUSFM).\(chapter).\(verseStart)-\(upperBookUSFM).\(chapter).\(verseEnd)"
            } else {
                return "\(upperBookUSFM).\(chapter).\(verseStart)"
            }
        } else {
            return "\(upperBookUSFM).\(chapter)"
        }
    }

    public func overlaps(with otherReference: BibleReference) -> Bool {
        guard versionId == otherReference.versionId &&
                bookUSFM == otherReference.bookUSFM else {
            return false
        }

        let a = min(self, otherReference)
        let b = max(self, otherReference)
        if a.chapter != b.chapter {
            return false  // TODO change this when we support cross-chapter ranges
        }
        // Treat a reference with both verseStart and verseEnd nil as a whole chapter reference.
        // Whole chapter overlaps any reference within the same chapter.
        let aStart: Int
        let aEnd: Int
        if a.verseStart == nil && a.verseEnd == nil {
            aStart = 1
            aEnd = Int.max
        } else {
            aStart = a.verseStart ?? 1
            aEnd = a.verseEnd ?? aStart
        }

        let bStart: Int
        let bEnd: Int
        if b.verseStart == nil && b.verseEnd == nil {
            bStart = 1
            bEnd = Int.max
        } else {
            bStart = b.verseStart ?? 1
            bEnd = b.verseEnd ?? bStart
        }
        return aEnd >= bStart && bEnd >= aStart
    }

    public func contains(with otherReference: BibleReference) -> Bool {
        guard versionId == otherReference.versionId &&
                bookUSFM == otherReference.bookUSFM else {
            return false
        }

        if chapter != otherReference.chapter {
            return false  // TODO change this when we support cross-chapter ranges
        }
        
        // Treat a reference with both verseStart and verseEnd nil as a whole chapter reference.
        // Whole chapter contains any reference within the same chapter.
        let aStart: Int
        let aEnd: Int
        if verseStart == nil && verseEnd == nil {
            aStart = 1
            aEnd = Int.max
        } else {
            aStart = verseStart ?? 1
            aEnd = verseEnd ?? aStart
        }

        let bStart: Int
        let bEnd: Int
        if otherReference.verseStart == nil && otherReference.verseEnd == nil {
            bStart = 1
            bEnd = Int.max
        } else {
            bStart = otherReference.verseStart ?? 1
            bEnd = otherReference.verseEnd ?? bStart
        }
        
        return aStart <= bStart && aEnd >= bEnd
    }

    public func isAdjacentOrOverlapping(with otherReference: BibleReference) -> Bool {
        guard versionId == otherReference.versionId &&
                bookUSFM == otherReference.bookUSFM &&
                chapter == otherReference.chapter else {
            return false
        }
        
        let a = min(self, otherReference)
        let b = max(self, otherReference)
        
        if let lastVerseOfA = a.verseEnd ?? a.verseStart {
            let firstVerseOfB = b.verseStart ?? 1
            return lastVerseOfA + 1 >= firstVerseOfB
        } else {
            return true
        }
    }
    
    public static func referencesByMerging(references: [BibleReference]) -> [BibleReference] {
        var tmp = references
        tmp.sort()
        var i = 1
        while i < tmp.count {
            let previousReference = tmp[i - 1]
            let currentReference = tmp[i]
            if previousReference.isAdjacentOrOverlapping(with: currentReference) {
                tmp[i - 1] = referenceByMerging(a: previousReference, b: currentReference)
                tmp.remove(at: i)
            } else {
                i += 1
            }
        }
        return tmp
    }
    
    public static func referenceByMerging(a: BibleReference, b: BibleReference) -> BibleReference {
        assert(a.isAdjacentOrOverlapping(with: b), "This function requires the two references to be adjacent or overlapping.")
        
        if a.verseStart == nil {
            return a    // chapter reference
        }
        
        if b.verseStart == nil {
            return b    // chapter reference
        }
        
        let minReference = min(a, b)
        
        let lastVerseOfA = a.verseEnd ?? a.verseStart
        let lastVerseOfB = b.verseEnd ?? b.verseStart
        let firstVerse = min(a.verseStart!, b.verseStart!)
        let lastVerse = max(lastVerseOfA!, lastVerseOfB!)
        return BibleReference(
            versionId: minReference.versionId,
            bookUSFM: minReference.bookUSFM,
            chapter: minReference.chapter,
            verseStart: firstVerse,
            verseEnd: lastVerse
        )
    }
    
    public static func unvalidatedReference(with usfm: String, versionId: Int) -> BibleReference? {
        func reference(bookUSFM: String, chapter: Int, verseStart: Int, verseEnd: Int) -> BibleReference? {
            if verseStart > verseEnd {
                return nil
            }
            return BibleReference(versionId: versionId, bookUSFM: bookUSFM, chapter: chapter, verseStart: verseStart, verseEnd: verseEnd)
        }
        
        // GEN.1.3-1.5
        let patBCVCV = /(\w\w\w)\.(\d+)\.(\d+)-(\d+)\.(\d+)/
        if let match = usfm.wholeMatch(of: patBCVCV) {
            let (_, bText, cText, vText, _, v2Text) = match.output
            if let c = Int(cText), let v = Int(vText), let v2 = Int(v2Text) {
                return reference(bookUSFM: bText.uppercased(), chapter: c, verseStart: v, verseEnd: v2)
            }
            return nil
        }
        
        // GEN.1.3-GEN.1.5
        let patBCVBCV = /(\w\w\w)\.(\d+)\.(\d+)-(\w\w\w)\.(\d+)\.(\d+)/
        if let match = usfm.wholeMatch(of: patBCVBCV) {
            let (_, bText, cText, vText, b2Text, _, v2Text) = match.output
            if let c = Int(cText), let v = Int(vText), let v2 = Int(v2Text) {
                if String(bText) != String(b2Text) {
                    return nil
                }
                return reference(bookUSFM: bText.uppercased(), chapter: c, verseStart: v, verseEnd: v2)
            }
            return nil
        }
        
        // GEN.1.3-5
        let patBCVV = /(\w\w\w)\.(\d+)\.(\d+)-(\d+)/
        if let match = usfm.wholeMatch(of: patBCVV) {
            let (_, bText, cText, vText, v2Text) = match.output
            if let c = Int(cText), let v = Int(vText), let v2 = Int(v2Text) {
                return reference(bookUSFM: bText.uppercased(), chapter: c, verseStart: v, verseEnd: v2)
            }
            return nil
        }
        
        // GEN.1.3
        let patBCV = /(\w\w\w)\.(\d+)\.(\d+)/
        if let match = usfm.wholeMatch(of: patBCV) {
            let (_, bText, cText, vText) = match.output
            if let c = Int(cText), let v = Int(vText) {
                return reference(bookUSFM: bText.uppercased(), chapter: c, verseStart: v, verseEnd: v)
            }
            return nil
        }
        
        // GEN.1
        let patBC = /(\w\w\w)\.(\d+)/
        if let match = usfm.wholeMatch(of: patBC) {
            let (_, bText, cText) = match.output
            if let c = Int(cText) {
                return reference(bookUSFM: bText.uppercased(), chapter: c, verseStart: 1, verseEnd: 1)
            }
            return nil
        }
        
        // GEN.1-2
        let patBCC = /(\w\w\w)\.(\d+)-(\d+)/
        if let match = usfm.wholeMatch(of: patBCC) {
            let (_, bText, cText, _) = match.output
            if let c = Int(cText) {
                return reference(bookUSFM: bText.uppercased(), chapter: c, verseStart: 1, verseEnd: 1)
            }
            return nil
        }
        
        return nil
    }
}
