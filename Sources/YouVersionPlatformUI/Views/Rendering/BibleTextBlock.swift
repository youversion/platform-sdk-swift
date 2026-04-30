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
    public let alignment: TextAlignment
    public let footnotes: [BibleFootnote]

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
        self.alignment = alignment
        self.footnotes = footnotes
        self.rows = rows
    }
}
