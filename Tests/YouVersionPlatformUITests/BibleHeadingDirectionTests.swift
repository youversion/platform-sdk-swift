import CoreText
import SwiftUI
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

@MainActor
struct BibleHeadingDirectionTests {
    @Test(arguments: ["א Aleph", "ב Beth", "ג Gimel", "נ Nun", "ש Sin and Shin"])
    func hebrewAcrosticLetterPrecedesEnglishName(heading: String) async throws {
        let blocks = try await headingBlocks(heading)
        let block = try #require(blocks.first)
        let original = block.text.asAttributedString
        let displayed = BibleTextView.textForDisplay(original, layoutDirection: .leftToRight)
        let characters = String(displayed.characters)

        #expect(String(original.characters) == heading)
        #expect(String(block.text.asAttributedString.characters) == heading)
        #expect(characters == "\u{200e}" + heading)
        #expect(displayed.runs.first?.attributes == original.runs.first?.attributes)
        #expect(horizontalOffset(in: characters, at: 1) < horizontalOffset(in: characters, at: 3))
        #expect(block.firstVerse == nil)
    }

    @Test func rightToLeftVersionKeepsRightToLeftHeadingOrder() async throws {
        let block = try #require(try await headingBlocks("א Aleph").first)
        let displayed = BibleTextView.textForDisplay(block.text.asAttributedString, layoutDirection: .rightToLeft)
        let characters = String(displayed.characters)

        #expect(characters == "\u{200f}א Aleph")
        #expect(horizontalOffset(in: characters, at: 1) > horizontalOffset(in: characters, at: 3))
    }

    @Test func rightToLeftVersionDirectsLatinLeadingHeading() async throws {
        let block = try #require(try await headingBlocks("Aleph א").first)
        let displayed = BibleTextView.textForDisplay(block.text.asAttributedString, layoutDirection: .rightToLeft)
        let characters = String(displayed.characters)

        #expect(characters == "\u{200f}Aleph א")
        #expect(horizontalOffset(in: characters, at: 1) > horizontalOffset(in: characters, at: 7))
    }

    @Test(arguments: ["\u{200e}", "\u{200f}", "\u{061c}"])
    func versionDirectionPrecedesExistingDirectionMark(mark: String) async throws {
        let block = try #require(try await headingBlocks(mark + "א Aleph").first)
        let original = block.text.asAttributedString
        let leftToRight = BibleTextView.textForDisplay(original, layoutDirection: .leftToRight)
        let rightToLeft = BibleTextView.textForDisplay(original, layoutDirection: .rightToLeft)

        #expect(horizontalOffset(in: String(leftToRight.characters), at: 2)
                < horizontalOffset(in: String(leftToRight.characters), at: 4))
        #expect(horizontalOffset(in: String(rightToLeft.characters), at: 2)
                > horizontalOffset(in: String(rightToLeft.characters), at: 4))
        #expect(String(block.text.asAttributedString.characters) == mark + "א Aleph")
    }

    @Test func scriptureTextAndReferencesStayUnchanged() async throws {
        let block = try #require(try await headingBlocks("א Aleph").last)
        let original = block.text.asAttributedString

        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            #expect(BibleTextView.textForDisplay(original, layoutDirection: direction) == original)
        }
        #expect(block.firstVerse == 1)
        #expect(original.runs[\.bibleReference].contains { $0.0?.verseStart == 1 })
    }

    @Test func emptyTextStaysEmpty() {
        let empty = AttributedString()
        #expect(BibleTextView.textForDisplay(empty, layoutDirection: .leftToRight) == empty)
    }

    private func headingBlocks(_ heading: String) async throws -> [BibleTextBlock] {
        let node = try BibleTextNode(html: """
        <div>
        <div class="qa"><span class="heading">\(heading)</span></div>
        <div class="q1"><span class="yv-v" v="1"></span>Verse text.</div>
        </div>
        """)
        return try #require(try await BibleVersionRendering.textBlocks(
            from: node,
            reference: BibleReference(versionId: 111, bookId: "PSA", chapter: 119),
            fonts: BibleTextFonts(familyName: "Times New Roman")
        ))
    }

    private func horizontalOffset(in text: String, at index: Int) -> CGFloat {
        let attributedText = NSAttributedString(string: text)
        let line = CTLineCreateWithAttributedString(attributedText)
        return CTLineGetOffsetForStringIndex(line, index, nil)
    }
}
