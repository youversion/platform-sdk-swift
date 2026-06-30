import Foundation
import SwiftUI

public struct BibleTextBlock: Identifiable {
    public let id = UUID()
    public let text: BibleAttributedString
    public let chapter: Int
    public let rows: [[BibleAttributedString]]  // If it's a table, these are present instead of "text".
    public let firstLineHeadIndent: Int  // The indentation of the first line of the paragraph. Always >= 0.
    public let headIndent: Int  // The indentation of the paragraph’s lines other than the first. Always >= 0.
    public let marginTop: CGFloat
    public let marginBottom: CGFloat
    public let alignment: TextAlignment
    public let footnotes: [BibleFootnote]

    /// The first verse this block displays, or nil when it shows none.
    public var firstVerse: Int? {
        text.asAttributedString.runs[\.bibleTextCategory, \.bibleReference]
            .first { category, _, _ in category == .scripture || category == .verseLabel }?
            .1?.verseStart
    }

    public init(
        text: BibleAttributedString,
        chapter: Int,
        firstLineHeadIndent: Int,
        headIndent: Int,
        marginTop: CGFloat,
        marginBottom: CGFloat,
        alignment: TextAlignment,
        footnotes: [BibleFootnote],
        rows: [[BibleAttributedString]] = []
    ) {
        self.text = text
        self.chapter = chapter
        self.firstLineHeadIndent = firstLineHeadIndent
        self.headIndent = headIndent
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.alignment = alignment
        self.footnotes = footnotes
        self.rows = rows
    }

    public init(
        text: BibleAttributedString,
        chapter: Int,
        firstLineHeadIndent: Int,
        headIndent: Int,
        marginTop: CGFloat,
        alignment: TextAlignment,
        footnotes: [BibleFootnote],
        rows: [[BibleAttributedString]] = []
    ) {
        self.text = text
        self.chapter = chapter
        self.firstLineHeadIndent = firstLineHeadIndent
        self.headIndent = headIndent
        self.marginTop = marginTop
        self.marginBottom = 0
        self.alignment = alignment
        self.footnotes = footnotes
        self.rows = rows
    }
}
