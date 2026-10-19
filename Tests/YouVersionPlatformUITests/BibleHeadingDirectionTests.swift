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

    @Test(arguments: [("א", "ALEPH"), ("ב", "BETH"), ("ג", "GIMEL")])
    func bsbStandaloneHebrewLetterKeepsSeparateNameHeading(letter: String, name: String) async throws {
        let node = try BibleTextNode(html: """
        <div><div class="qa yv-h">\(letter)</div><div class="qa yv-h">\(name)</div></div>
        """)
        let blocks = try #require(try await BibleVersionRendering.textBlocks(
            from: node,
            reference: BibleReference(versionId: 3034, bookId: "PSA", chapter: 119),
            fonts: BibleTextFonts(familyName: "Times New Roman")
        ))

        #expect(blocks.count == 2)
        #expect(blocks.map { String($0.text.asAttributedString.characters) } == [letter, name])
        for block in blocks {
            let original = block.text.asAttributedString
            let displayed = BibleTextView.textForDisplay(original, layoutDirection: .leftToRight)
            #expect(String(displayed.characters.dropFirst()) == String(original.characters))
            #expect(displayed.runs.first?.attributes == original.runs.first?.attributes)
        }
    }

    @Test(arguments: [
        (1498, "تئیی شَریَت منا دۆست اِنت", LayoutDirection.leftToRight),
        (3327, "अल्लाह के कलाम की शान", LayoutDirection.rightToLeft)
    ])
    func oppositeScriptHeadingUsesReportedVersionDirection(versionId: Int, heading: String, direction: LayoutDirection) async throws {
        let block = try #require(try await headingBlocks(heading, versionId: versionId, blockClass: "s yv-h").first)
        let original = block.text.asAttributedString
        let displayed = BibleTextView.textForDisplay(original, layoutDirection: direction)
        let directionMark = direction == .rightToLeft ? "\u{200f}" : "\u{200e}"

        #expect(String(displayed.characters) == directionMark + heading)
        #expect(String(block.text.asAttributedString.characters) == heading)
        #expect(displayed.runs.first?.attributes == original.runs.first?.attributes)
        #expect(block.firstVerse == nil)
    }

    /// Synthetic punctuation cases make version-directed paragraph flow explicit;
    /// these alphabet samples are not quotations from cached Bible headings.
    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func entirelyRightToLeftHeadingKeepsLetterOrderAndVersionPunctuation(direction: LayoutDirection) async throws {
        let block = try #require(try await headingBlocks("אבג!").first)
        let original = block.text.asAttributedString
        let displayed = BibleTextView.textForDisplay(original, layoutDirection: direction)
        let positions = try glyphPositions(in: String(displayed.characters))
        let aleph = try #require(positions[1])
        let beth = try #require(positions[2])
        let gimel = try #require(positions[3])
        let punctuation = try #require(positions[4])

        #expect(aleph > beth && beth > gimel)
        if direction == .leftToRight {
            #expect(punctuation > aleph)
        } else {
            #expect(punctuation < gimel)
        }
        #expect(String(block.text.asAttributedString.characters) == "אבג!")
    }

    /// Mirrors the opposite-script case for Latin text in an RTL version.
    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func entirelyLeftToRightHeadingKeepsLetterOrderAndVersionPunctuation(direction: LayoutDirection) async throws {
        let block = try #require(try await headingBlocks("ABC!").first)
        let original = block.text.asAttributedString
        let displayed = BibleTextView.textForDisplay(original, layoutDirection: direction)
        let positions = try glyphPositions(in: String(displayed.characters))
        let firstLetter = try #require(positions[1])
        let secondLetter = try #require(positions[2])
        let thirdLetter = try #require(positions[3])
        let punctuation = try #require(positions[4])

        #expect(firstLetter < secondLetter && secondLetter < thirdLetter)
        if direction == .leftToRight {
            #expect(punctuation > thirdLetter)
        } else {
            #expect(punctuation < firstLetter)
        }
        #expect(String(block.text.asAttributedString.characters) == "ABC!")
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

    private func headingBlocks(_ heading: String, versionId: Int = 111, blockClass: String = "qa") async throws -> [BibleTextBlock] {
        let node = try BibleTextNode(html: """
        <div>
        <div class="\(blockClass)"><span class="heading">\(heading)</span></div>
        <div class="q1"><span class="yv-v" v="1"></span>Verse text.</div>
        </div>
        """)
        return try #require(try await BibleVersionRendering.textBlocks(
            from: node,
            reference: BibleReference(versionId: versionId, bookId: "PSA", chapter: 119),
            fonts: BibleTextFonts(familyName: "Times New Roman")
        ))
    }

    private func horizontalOffset(in text: String, at index: Int) -> CGFloat {
        let attributedText = NSAttributedString(string: text)
        let line = CTLineCreateWithAttributedString(attributedText)
        return CTLineGetOffsetForStringIndex(line, index, nil)
    }

    private func glyphPositions(in text: String) throws -> [Int: CGFloat] {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text))
        let runs = try #require(CTLineGetGlyphRuns(line) as? [CTRun])
        var positionsByIndex: [Int: CGFloat] = [:]
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            var indices = [CFIndex](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &indices)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for (index, position) in zip(indices, positions) {
                positionsByIndex[index] = position.x
            }
        }
        return positionsByIndex
    }
}
