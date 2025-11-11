import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum BibleTextFontOption {
    case textFont
    case textFontItalic
    case verseNumFont
    case smallCaps
    case header
    case headerItalic
    case headerSmaller
    case header2
    case header3
    case header4
    case footnote
}

public struct BibleTextFonts {
    var fonts: [BibleTextFontOption: Font]

    public let baseSize: CGFloat
    public let verseNumBaselineOffset: CGFloat
    public let verseNumOpacity: CGFloat

    public func font(for option: BibleTextFontOption) -> Font {
        fonts[option]!
    }

    public init(familyName: String, baseSize origBaseSize: CGFloat? = nil) {
#if canImport(UIKit)
        let baseSize = origBaseSize ?? UIFont.preferredFont(forTextStyle: .body).pointSize
        //print("baseSize = \(baseSize); family=\(familyName)")
#else
        let baseSize = 17.0
#endif
        self.baseSize = baseSize
        verseNumBaselineOffset = baseSize * 0.3
        verseNumOpacity = 0.7
        let boldFamilyName: String // = familyName == "UntitledSerif-Regular" ? "UntitledSerif-Bold" : familyName
        let italicFamilyName: String
        let boldItalicFamilyName: String
        if familyName.hasSuffix("-Regular") {
            let base = familyName.split(separator: "-").dropLast().joined(separator: "-")
            boldFamilyName = base + "-Bold"
            italicFamilyName = base + "-Italic"
            boldItalicFamilyName = base + "-BoldItalic"
        } else {
            boldFamilyName = familyName
            italicFamilyName = familyName
            boldItalicFamilyName = familyName
        }

        let larger = Font.custom(familyName, fixedSize: baseSize * 1.1)
        fonts = [
            .textFont: Font.custom(familyName, fixedSize: baseSize),
            .textFontItalic: Font.custom(italicFamilyName, fixedSize: baseSize),
            .verseNumFont: Font.custom(familyName, fixedSize: baseSize * 0.7).smallCaps(),
            .smallCaps: Font.custom(familyName, fixedSize: baseSize).lowercaseSmallCaps(),
            .header: Font.custom(italicFamilyName, fixedSize: baseSize * 1.2).italic(),
            .headerItalic: Font.custom(italicFamilyName, fixedSize: baseSize * 1.1).italic(),
            .headerSmaller: Font.custom(boldItalicFamilyName, fixedSize: baseSize * 0.9).weight(.medium).italic(),
            .header2: Font.custom(boldFamilyName, fixedSize: baseSize * 1.1).weight(.bold),
            .header3: larger,
            .header4: larger,
            .footnote: Font.custom(familyName, fixedSize: baseSize * 0.8)
        ]
    }
}
