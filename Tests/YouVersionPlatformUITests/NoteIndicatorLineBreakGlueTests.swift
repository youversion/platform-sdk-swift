import CoreText
import Foundation
import Testing

/// Pins the Unicode line-breaking contract `BibleTextView+Rendering.swift` relies on to fix
/// BL-1977: a word joiner (U+2060) after each of the note-indicator badge's space characters
/// must prevent CoreText from ever suggesting a line break inside the badge, while still
/// allowing a break at the ordinary trailing space that follows it.
@Suite struct NoteIndicatorLineBreakGlueTests {
    // Mirrors the literal sequence BibleTextView+Rendering.swift builds for a note badge:
    // EM SPACE (pencil placeholder) + WJ, THIN SPACE (spacer) + WJ, then the verse number.
    private static let badge = "\u{2003}\u{2060}\u{2009}\u{2060}12"
    private static let trailingSpace = " "
    private static let nextWord = "next"

    @Test
    func wordJoinerPreventsBreakInsideNoteBadge() throws {
        let full = Self.badge + Self.trailingSpace + Self.nextWord
        let font = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        let badgeLine = CTLineCreateWithAttributedString(NSAttributedString(string: Self.badge, attributes: attrs))
        let badgeWidth = CTLineGetTypographicBounds(badgeLine, nil, nil, nil)

        let typesetter = CTTypesetterCreateWithAttributedString(NSAttributedString(string: full, attributes: attrs))
        // Constrain to just enough width for the badge alone -- any break CoreText offers
        // within that width must land at/after the badge's end, never inside it.
        let breakIndex = CTTypesetterSuggestLineBreak(typesetter, 0, badgeWidth + 2)

        #expect(breakIndex >= (Self.badge as NSString).length)
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
