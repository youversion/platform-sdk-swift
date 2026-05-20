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

        if familyName.hasSuffix("-Regular") {
            let base = familyName.split(separator: "-").dropLast().joined(separator: "-")
            boldFamilyName = base + "-Bold"
            italicFamilyName = base + "-Italic"
        } else {
            boldFamilyName = familyName
            italicFamilyName = familyName
        }

        fonts = [
            .textFontItalic: Self.font(familyName: italicFamilyName, size: baseSize).italic(),
            .textFontBold: Self.font(familyName: boldFamilyName, size: baseSize).bold(),
            .smallCaps: Self.font(familyName: familyName, size: baseSize).lowercaseSmallCaps(),
            .headerItalic: Self.font(familyName: italicFamilyName, size: baseSize * 1.1).italic(),
            .headerSmaller: Self.font(familyName: boldFamilyName, size: baseSize * 0.9).weight(.medium),
            .header2: Self.font(familyName: boldFamilyName, size: baseSize * 1.1).weight(.bold),
            .header3: Self.font(familyName: familyName, size: baseSize * 1.1),
            .header4: Self.font(familyName: familyName, size: baseSize * 1.1),
            .footnote: Self.font(familyName: familyName, size: baseSize * 0.8),
            // below are validated standards:
            .header: Self.font(familyName: boldFamilyName, size: baseSize).bold(),
            .headerSmallerItalic: Self.font(familyName: italicFamilyName, size: baseSize * 0.76).italic(),
            .textFont: Self.font(familyName: familyName, size: baseSize),
            .verseNumFont: Self.font(familyName: familyName, size: baseSize * 0.65).smallCaps()
        ]
    }

    private static func font(familyName: String, size: CGFloat) -> Font {
        if familyName == "San Francisco" || familyName == "SF Pro Text" || familyName.hasPrefix("SFProText-") {
            return Font.system(size: size)
        }

        if familyName == "New York" || familyName.hasPrefix("NewYork-") {
            return Font.system(size: size, design: .serif)
        }

        return Font.custom(familyName, fixedSize: size)
    }
}
