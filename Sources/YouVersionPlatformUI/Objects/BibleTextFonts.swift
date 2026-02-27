import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum BibleTextFontOption {
    case textFont
    case textFontBold
    case textFontItalic
    case verseNumFont
    case smallCaps
    case header
    case headerItalic
    case headerSmaller
    case headerSmallerItalic
    case header2
    case header3
    case header4
    case footnote
}

public struct BibleTextFonts {
    var fonts: [BibleTextFontOption: Font]

    public let baseSize: CGFloat
    public let verseNumBaselineOffset: CGFloat

    public func font(for option: BibleTextFontOption) -> Font {
        fonts[option]!
    }

    public init(familyName: String, baseSize origBaseSize: CGFloat? = nil) {
#if canImport(UIKit)
        let baseSize = origBaseSize ?? UIFont.preferredFont(forTextStyle: .body).pointSize
#else
        let baseSize = 21.0
#endif
        self.baseSize = baseSize
        verseNumBaselineOffset = baseSize * 0.3
        let boldFamilyName: String
        let italicFamilyName: String
        //let boldItalicFamilyName: String
        if familyName.hasSuffix("-Regular") {
            let base = familyName.split(separator: "-").dropLast().joined(separator: "-")
            boldFamilyName = base + "-Bold"
            italicFamilyName = base + "-Italic"
            //boldItalicFamilyName = base + "-BoldItalic"
        } else {
            boldFamilyName = familyName
            italicFamilyName = familyName
            //boldItalicFamilyName = familyName
        }

        let larger = Font.custom(familyName, fixedSize: baseSize * 1.1)
        fonts = [
            .textFontItalic: Font.custom(italicFamilyName, fixedSize: baseSize).italic(),
            .textFontBold: Font.custom(boldFamilyName, fixedSize: baseSize).bold(),
            .smallCaps: Font.custom(familyName, fixedSize: baseSize).lowercaseSmallCaps(),
            .headerItalic: Font.custom(italicFamilyName, fixedSize: baseSize * 1.1).italic(),
            .headerSmaller: Font.custom(boldFamilyName, fixedSize: baseSize * 0.9).weight(.medium),
            .header2: Font.custom(boldFamilyName, fixedSize: baseSize * 1.1).weight(.bold),
            .header3: larger,
            .header4: larger,
            .footnote: Font.custom(familyName, fixedSize: baseSize * 0.8),
            // below are validated standards:
            .header: Font.custom(boldFamilyName, fixedSize: baseSize).bold(),
            .headerSmallerItalic: Font.custom(italicFamilyName, fixedSize: baseSize * 0.76).italic(),
            .textFont: Font.custom(familyName, fixedSize: baseSize),
            .verseNumFont: Font.custom(familyName, fixedSize: baseSize * 0.65).smallCaps()
        ]
    }
}
