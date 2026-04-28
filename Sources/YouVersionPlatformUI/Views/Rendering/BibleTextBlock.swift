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
    public let alignment: TextAlignment
    public let footnotes: [BibleFootnote]

    public init(
        text: BibleAttributedString,
        chapter: Int,
        startVerse: Int? = nil,
        firstLineHeadIndent: Int,
        headIndent: Int,
        marginTop: CGFloat,
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
        self.alignment = alignment
        self.footnotes = footnotes
        self.rows = rows
    }

    /// Stable identifier combining chapter and verse for use with `ScrollViewReader`.
    var verseAnchorId: String? {
        guard let startVerse else {
            return nil
        }
        return "ch\(chapter)v\(startVerse)"
    }
}
