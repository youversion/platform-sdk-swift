import SwiftUI
import Testing
@testable import YouVersionPlatformUI

struct YouVersionFontsTests {
    @Test
    func reportsAvailableFontFamily() {
        #expect(YouVersionFonts.isFontFamilyAvailable("Helvetica"))
    }

    @Test
    func reportsUnavailableFontFamily() {
        #expect(!YouVersionFonts.isFontFamilyAvailable("Definitely Not A Font Family"))
    }
}

@MainActor
struct BibleTextFontTests {
    /// Keeps shorthand calls and typed method references source-compatible for both APIs.
    @Test func supportsExistingCallsAndNewPresets() {
        let fonts = BibleTextFonts(familyName: "Times New Roman", baseSize: 20)
        let legacyLookup: (BibleTextFontOption) -> Font = fonts.font(for:)
        let presetLookup: (BibleTextFont) -> Font = fonts.font(for:)
        let inferredLegacyLookup = fonts.font(for:)
        let option = BibleTextFontOption.font100em
        let baseSize = fonts.baseSize
        let regularFont = Font.custom("Times New Roman", fixedSize: baseSize)
        #expect(fonts.font(for: .font100em) == regularFont)
        #expect(legacyLookup(.font100em) == regularFont)
        #expect(inferredLegacyLookup(option) == regularFont)
        #expect(presetLookup(.font100em) == regularFont)
        #expect(BibleTextFont(BibleTextFontOption.font100em) == .font100em)
        #expect(presetLookup(.font130emItalic) == Font.custom("Times New Roman", fixedSize: baseSize * 1.3).italic())
        #expect(presetLookup(.font160em700) == Font.custom("Times New Roman", fixedSize: baseSize * 1.6).weight(.bold))
        #expect(fonts.font(for: .font130emItalic) == presetLookup(.font130emItalic))

        let text = BibleAttributedString("Text")
        let legacySetter: (BibleTextFontOption, BibleTextFonts, Bool) -> BibleAttributedString = text.setFont
        let presetSetter: (BibleTextFont, BibleTextFonts, Bool) -> BibleAttributedString = text.setFont
        let inferredLegacySetter = text.setFont
        #expect(text.setFont(.font100em, from: fonts) === text)
        #expect(legacySetter(.font100em, fonts, true).asAttributedString.font == regularFont.lowercaseSmallCaps())
        #expect(presetSetter(.font100em, fonts, true).asAttributedString.font == regularFont.lowercaseSmallCaps())
        #expect(inferredLegacySetter(option, fonts, false).asAttributedString.font == regularFont)
        #expect(text.setFont(.font160em700, from: fonts).asAttributedString.font == presetLookup(.font160em700))
    }

    /// Preserves every existing enum option's font, including the deprecated variants.
    @Test func preservesExistingFontOutput() {
        let fonts = BibleTextFonts(familyName: "TimesNewRomanPS-Regular", baseSize: 20)
        let baseSize = fonts.baseSize
        let regularFont = Font.custom("TimesNewRomanPS-Regular", fixedSize: baseSize)
        let italicFont = Font.custom("TimesNewRomanPS-Italic", fixedSize: baseSize).italic()
        let legacy = BibleTextFontOption.self as DeprecatedFontOptions.Type
        let expectations: [(option: BibleTextFontOption, font: Font)] = [
            (.font076emItalic, Font.custom("TimesNewRomanPS-Italic", fixedSize: baseSize * 0.76).italic()),
            (.font083emItalic, Font.custom("TimesNewRomanPS-Italic", fixedSize: baseSize * 0.83).italic()),
            (.font100em, regularFont),
            (.font100emItalic, italicFont),
            (.font100em500, regularFont.weight(.medium)),
            (.font100em500Italic, Font.custom("TimesNewRomanPS-Italic", fixedSize: baseSize).weight(.medium).italic()),
            (.font100em700, regularFont.weight(.bold)),
            (.font108emItalic, Font.custom("TimesNewRomanPS-Italic", fixedSize: baseSize * 1.08).italic()),
            (.font117em500, Font.custom("TimesNewRomanPS-Regular", fixedSize: baseSize * 1.17).weight(.medium)),
            (.font117em500Italic, Font.custom("TimesNewRomanPS-Italic", fixedSize: baseSize * 1.17).weight(.medium).italic()),
            (.font117em700, Font.custom("TimesNewRomanPS-Regular", fixedSize: baseSize * 1.17).weight(.bold)),
            (.footnote, Font.custom("TimesNewRomanPS-Regular", fixedSize: baseSize * 0.8)),
            (.verseNumFont, Font.custom("Helvetica Neue", fixedSize: baseSize * 0.65).smallCaps()),
            (legacy.textFont, regularFont),
            (legacy.textFontBold, regularFont.bold()),
            (legacy.textFontItalic, italicFont),
            (legacy.smallCaps, regularFont.lowercaseSmallCaps()),
            (legacy.header, regularFont.bold()),
            (legacy.headerItalic, Font.custom("TimesNewRomanPS-Italic", fixedSize: baseSize * 1.1).italic()),
            (legacy.headerSmaller, Font.custom("TimesNewRomanPS-Regular", fixedSize: baseSize * 0.9).weight(.medium)),
            (legacy.headerSmallerItalic, Font.custom("TimesNewRomanPS-Italic", fixedSize: baseSize * 0.76).italic()),
            (legacy.header2, Font.custom("TimesNewRomanPS-Regular", fixedSize: baseSize * 1.1).weight(.bold)),
            (legacy.header3, Font.custom("TimesNewRomanPS-Regular", fixedSize: baseSize * 1.1)),
            (legacy.header4, Font.custom("TimesNewRomanPS-Regular", fixedSize: baseSize * 1.1)),
            (legacy.font100emSmallCaps, regularFont.lowercaseSmallCaps())
        ]
        for expectation in expectations {
            let preset = BibleTextFont(expectation.option)
            #expect(fonts.font(for: expectation.option) == expectation.font)
            #expect(fonts.font(for: preset) == expectation.font)
            let legacyText = BibleAttributedString("Text").setFont(expectation.option, from: fonts)
            let presetText = BibleAttributedString("Text").setFont(preset, from: fonts)
            #expect(legacyText.asAttributedString.font == expectation.font)
            #expect(presetText == legacyText)
        }
    }
}

private protocol DeprecatedFontOptions {
    static var textFont: BibleTextFontOption { get }
    static var textFontBold: BibleTextFontOption { get }
    static var textFontItalic: BibleTextFontOption { get }
    static var smallCaps: BibleTextFontOption { get }
    static var header: BibleTextFontOption { get }
    static var headerItalic: BibleTextFontOption { get }
    static var headerSmaller: BibleTextFontOption { get }
    static var headerSmallerItalic: BibleTextFontOption { get }
    static var header2: BibleTextFontOption { get }
    static var header3: BibleTextFontOption { get }
    static var header4: BibleTextFontOption { get }
    static var font100emSmallCaps: BibleTextFontOption { get }
}

extension BibleTextFontOption: DeprecatedFontOptions {}
