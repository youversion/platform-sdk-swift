import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Legacy font options. Use `BibleTextFont` presets for new code.
public enum BibleTextFontOption {
    case font076emItalic
    case font083emItalic
    case font100em
    case font100emItalic
    case font100em500
    case font100em500Italic
    case font100em700
    case font108emItalic
    case font117em500
    case font117em500Italic
    case font117em700
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
    @available(*, deprecated, message: "set inSmallcaps instead")
    case font100emSmallCaps
}

public struct BibleTextFonts {
    private let fonts: [BibleTextFont: Font]

    public let baseSize: CGFloat
    public let verseNumBaselineOffset: CGFloat

    public init(familyName: String, baseSize origBaseSize: CGFloat? = nil) {
#if canImport(UIKit)
        let baseSize = origBaseSize ?? UIFont.preferredFont(forTextStyle: .body).pointSize
#else
        let baseSize = 21.0
#endif
        self.baseSize = baseSize
        verseNumBaselineOffset = baseSize * 0.2
        fonts = BibleTextFont.fonts(familyName: familyName, baseSize: baseSize)
    }

    /// Returns the font for an existing enum option.
    public func font(for option: BibleTextFontOption) -> Font {
        font(for: BibleTextFont(option))
    }

    /// Returns the font for a Bible text preset.
    @_disfavoredOverload
    public func font(for preset: BibleTextFont) -> Font {
        fonts[preset]!
    }
}
