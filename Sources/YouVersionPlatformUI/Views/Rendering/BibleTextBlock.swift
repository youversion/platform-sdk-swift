import Foundation
import SwiftUI

public struct BibleTextBlock: Identifiable {
    public let id = UUID()
    public let text: BibleAttributedString
    public let chapter: Int
    public let startVerse: Int?
    public let rows: [[BibleAttributedString]]  // If it's a table, these are present instead of "text".
    public let firstLineHeadIndent: Int  // The indentation of the first line of the paragraph. Always >= 0.
    public let headIndent: Int  // The indentation of the paragraph’s lines other than the first. Always >= 0.
    public let marginTop: CGFloat
    public let marginBottom: CGFloat
    public let alignment: TextAlignment
    public let footnotes: [BibleFootnote]
    public let firstVerse: Int? // The first verse this block displays, or nil when it shows none.

    public init(
        text: BibleAttributedString,
        chapter: Int,
        startVerse: Int? = nil,
        firstLineHeadIndent: Int,
        headIndent: Int,
        marginTop: CGFloat,
        marginBottom: CGFloat = 0,
        alignment: TextAlignment,
        footnotes: [BibleFootnote],
        rows: [[BibleAttributedString]] = []
    ) {
        self.text = text
        self.chapter = chapter
        self.startVerse = startVerse
        self.firstLineHeadIndent = firstLineHeadIndent
        self.headIndent = headIndent
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.alignment = alignment
        self.footnotes = footnotes
        self.rows = rows
        self.firstVerse = Self.firstVerse(in: text)
    }

    private static func firstVerse(in text: BibleAttributedString) -> Int? {
        let runs = text.asAttributedString.runs[\.bibleTextCategory, \.bibleReference]
        let firstScriptureRun = runs.first { category, _, _ in
            category == .scripture || category == .verseLabel
        }
        let reference = firstScriptureRun?.1
        return reference?.verseStart
    }

    /// Stable identifier combining chapter and verse for use with `ScrollViewReader`.
    var verseAnchorId: String? {
        guard let startVerse else {
            return nil
        }
        return "ch\(chapter)v\(startVerse)"
    }

    /// Splits this block at Bible-reference run boundaries so each result contains no more than the requested verses.
    /// Each result preserves the original layout metadata and receives only the footnotes referenced by its text.
    func split(maximumVerseCount: Int) -> [BibleTextBlock] {
        let attributedString = text.asAttributedString
        var previousVerse: Int?
        var verseCount = 0
        let splitIndexes = attributedString.runs[\.bibleReference].compactMap { reference, range -> AttributedString.Index? in
            guard let verse = reference?.verseStart, verse != previousVerse else {
                return nil
            }
            previousVerse = verse
            if verseCount == maximumVerseCount {
                verseCount = 1
                return range.lowerBound
            }
            verseCount += 1
            return nil
        }

        guard !splitIndexes.isEmpty else {
            return [self]
        }

        let boundaries = [attributedString.startIndex] + splitIndexes + [attributedString.endIndex]
        return zip(boundaries, boundaries.dropFirst()).enumerated().map { index, bounds in
            let slice = BibleAttributedString(AttributedString(attributedString[bounds.0..<bounds.1]))
            let references = Set(slice.asAttributedString.runs[\.bibleReference].compactMap { reference, _ in reference })
            return BibleTextBlock(
                text: slice,
                chapter: chapter,
                firstLineHeadIndent: firstLineHeadIndent,
                headIndent: headIndent,
                marginTop: index == 0 ? marginTop : 0,
                marginBottom: index == splitIndexes.count ? marginBottom : 0,
                alignment: alignment,
                footnotes: footnotes.filter { references.contains($0.reference) }
            )
        }
    }
}
