import CoreText
import Foundation
import Testing

/// Pins the Unicode line-breaking contract the note-indicator badge relies on: a word
/// joiner (U+2060) after each space character must block a break inside the badge, while
/// the ordinary trailing space after it stays breakable.
@Suite struct NoteIndicatorLineBreakGlueTests {
    // Mirrors the literal sequence BibleTextView+Rendering.swift builds for a note badge:
    // EM SPACE (pencil placeholder) + WJ, THIN SPACE (spacer) + WJ, then the verse number.
    private static let leadingWord = "word "
    private static let badge = "\u{2003}\u{2060}\u{2009}\u{2060}12"
    private static let trailingSpace = " "
    private static let nextWord = "next"

    @Test
    func wordJoinerPreventsBreakInsideNoteBadge() throws {
        let font = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        let leadingLine = CTLineCreateWithAttributedString(NSAttributedString(string: Self.leadingWord, attributes: attrs))
        let leadingWidth = CTLineGetTypographicBounds(leadingLine, nil, nil, nil)
        let badgeLine = CTLineCreateWithAttributedString(NSAttributedString(string: Self.badge, attributes: attrs))
        let badgeWidth = CTLineGetTypographicBounds(badgeLine, nil, nil, nil)

        let full = Self.leadingWord + Self.badge + Self.trailingSpace + Self.nextWord
        let typesetter = CTTypesetterCreateWithAttributedString(NSAttributedString(string: full, attributes: attrs))
        // Room for the leading word plus half the badge, but not the whole badge: with no
        // legal break inside it, the whole badge must defer to the next line.
        let breakIndex = CTTypesetterSuggestLineBreak(typesetter, 0, leadingWidth + badgeWidth / 2)

        #expect(breakIndex == (Self.leadingWord as NSString).length)
    }

    @Test
    func trailingSpaceAfterBadgeStaysBreakable() throws {
        let full = Self.badge + Self.trailingSpace + Self.nextWord
        let font = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        let upToNextWordLine = CTLineCreateWithAttributedString(
            NSAttributedString(string: Self.badge + Self.trailingSpace, attributes: attrs)
        )
        let upToNextWordWidth = CTLineGetTypographicBounds(upToNextWordLine, nil, nil, nil)

        let typesetter = CTTypesetterCreateWithAttributedString(NSAttributedString(string: full, attributes: attrs))
        // A width that fits the badge and its trailing space, but not "next", must still
        // offer a break right after the trailing space -- the badge-as-a-whole stays wrappable.
        let breakIndex = CTTypesetterSuggestLineBreak(typesetter, 0, upToNextWordWidth + 2)

        #expect(breakIndex == (Self.badge + Self.trailingSpace as NSString).length)
    }
}
