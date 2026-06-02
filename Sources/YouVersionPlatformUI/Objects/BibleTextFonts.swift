import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum BibleTextFontOption {
    case font076emItalic
    case font100em
    case font100emItalic
    case font100emSmallCaps
    case font100em500
    case font100em500Italic
    case font117em500
    case font117em500Italic
    case footnote
    case verseNumFont

    @available(*, deprecated, renamed: "font100em")
    case textFont
    @available(*, deprecated, renamed: "font100em500")
    case textFontBold
    @available(*, deprecated, renamed: "font100emItalic")
    case textFontItalic
    @available(*, deprecated, renamed: "font100emSmallCaps")
    case smallCaps
    @available(*, deprecated, renamed: "font117em500")
    case header
    @available(*, deprecated, renamed: "font117em500Italic")
    case headerItalic
    @available(*, deprecated, renamed: "font100em500")
    case headerSmaller
    @available(*, deprecated, renamed: "font100em500Italic")
    case headerSmallerItalic
    @available(*, deprecated, renamed: "font100em500")
    case header2
    @available(*, deprecated, renamed: "font100em500")
    case header3
    @available(*, deprecated, renamed: "font100em500")
    case header4
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
        verseNumBaselineOffset = baseSize * 0.2

        let italicFamilyName: String

        if familyName.hasSuffix("-Regular") {
            let base = familyName.split(separator: "-").dropLast().joined(separator: "-")
            italicFamilyName = base + "-Italic"
        } else {
            italicFamilyName = familyName
        }

        fonts = [
            .font076emItalic: Self.font(familyName: italicFamilyName, size: baseSize * 0.76).italic(),
            .font100em: Self.font(familyName: familyName, size: baseSize),
            .font100emItalic: Self.font(familyName: italicFamilyName, size: baseSize).italic(),
            .font100emSmallCaps: Self.font(familyName: familyName, size: baseSize).lowercaseSmallCaps(),
            .font100em500: Self.font(familyName: familyName, size: baseSize).weight(.medium),
            .font100em500Italic: Self.font(familyName: italicFamilyName, size: baseSize).weight(.medium).italic(),
            .font117em500: Self.font(familyName: familyName, size: baseSize * 1.17).weight(.medium),
            .font117em500Italic: Self.font(familyName: italicFamilyName, size: baseSize * 1.17).weight(.medium).italic(),
            .footnote: Self.font(familyName: familyName, size: baseSize * 0.8),
            .verseNumFont: Self.font(familyName: "Helvetica Neue", size: baseSize * 0.65).smallCaps(),
            
            // below are deprecated:
            .textFontItalic: Self.font(familyName: italicFamilyName, size: baseSize).italic(),
            .textFontBold: Self.font(familyName: familyName, size: baseSize).bold(),
            .smallCaps: Self.font(familyName: familyName, size: baseSize).lowercaseSmallCaps(),
            .headerItalic: Self.font(familyName: italicFamilyName, size: baseSize * 1.1).italic(),
            .headerSmaller: Self.font(familyName: familyName, size: baseSize * 0.9).weight(.medium),
            .header2: Self.font(familyName: familyName, size: baseSize * 1.1).weight(.bold),
            .header3: Self.font(familyName: familyName, size: baseSize * 1.1),
            .header4: Self.font(familyName: familyName, size: baseSize * 1.1),
            .header: Self.font(familyName: familyName, size: baseSize).bold(),
            .headerSmallerItalic: Self.font(familyName: italicFamilyName, size: baseSize * 0.76).italic(),
            .textFont: Self.font(familyName: familyName, size: baseSize)
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
