import SwiftUI

/// An extensible Bible text font preset.
public struct BibleTextFont: Hashable, Sendable {
    private enum Preset: CaseIterable, Hashable, Sendable {
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
        case font130emItalic
        case font160em700
        case footnote
        case verseNumFont
        case font130em
        case font130em500
        case font130em500Italic
        case font130em700
        case font160em
        case font160emItalic
        case font160em500
        case font160em500Italic
        case legacyBold
        case legacySmallCaps
        case legacyHeading
        case legacyHeadingBold
        case legacyHeadingItalic
        case legacySmallHeading
    }

    private let preset: Preset

    /// Italic text at 0.76 times the base size.
    public static let font076emItalic = BibleTextFont(preset: .font076emItalic)

    /// Italic text at 0.83 times the base size.
    public static let font083emItalic = BibleTextFont(preset: .font083emItalic)

    /// Regular text at the base size.
    public static let font100em = BibleTextFont(preset: .font100em)

    /// Italic text at the base size.
    public static let font100emItalic = BibleTextFont(preset: .font100emItalic)

    /// Medium-weight text at the base size.
    public static let font100em500 = BibleTextFont(preset: .font100em500)

    /// Medium-weight italic text at the base size.
    public static let font100em500Italic = BibleTextFont(preset: .font100em500Italic)

    /// Bold text at the base size.
    public static let font100em700 = BibleTextFont(preset: .font100em700)

    /// Italic text at 1.08 times the base size.
    public static let font108emItalic = BibleTextFont(preset: .font108emItalic)

    /// Medium-weight text at 1.17 times the base size.
    public static let font117em500 = BibleTextFont(preset: .font117em500)

    /// Medium-weight italic text at 1.17 times the base size.
    public static let font117em500Italic = BibleTextFont(preset: .font117em500Italic)

    /// Bold text at 1.17 times the base size.
    public static let font117em700 = BibleTextFont(preset: .font117em700)

    /// Italic text at 1.3 times the base size.
    public static let font130emItalic = BibleTextFont(preset: .font130emItalic)

    /// Bold text at 1.6 times the base size.
    public static let font160em700 = BibleTextFont(preset: .font160em700)

    /// Footnote text at 0.8 times the base size.
    public static let footnote = BibleTextFont(preset: .footnote)

    /// Small-cap verse labels at 0.65 times the base size.
    public static let verseNumFont = BibleTextFont(preset: .verseNumFont)

    private static let legacyBold = BibleTextFont(preset: .legacyBold)
    private static let legacySmallCaps = BibleTextFont(preset: .legacySmallCaps)
    private static let legacyHeading = BibleTextFont(preset: .legacyHeading)
    private static let legacyHeadingBold = BibleTextFont(preset: .legacyHeadingBold)
    private static let legacyHeadingItalic = BibleTextFont(preset: .legacyHeadingItalic)
    private static let legacySmallHeading = BibleTextFont(preset: .legacySmallHeading)

    /// Preserves the font represented by an existing enum option, including deprecated options.
    public init(_ option: BibleTextFontOption) {
        self = switch option {
        case .font076emItalic: .font076emItalic
        case .font083emItalic: .font083emItalic
        case .font100em: .font100em
        case .font100emItalic: .font100emItalic
        case .font100em500: .font100em500
        case .font100em500Italic: .font100em500Italic
        case .font100em700: .font100em700
        case .font108emItalic: .font108emItalic
        case .font117em500: .font117em500
        case .font117em500Italic: .font117em500Italic
        case .font117em700: .font117em700
        case .footnote: .footnote
        case .verseNumFont: .verseNumFont
        case .textFont: .font100em
        case .textFontBold: .legacyBold
        case .textFontItalic: .font100emItalic
        case .smallCaps: .legacySmallCaps
        case .header: .legacyBold
        case .headerItalic: .legacyHeadingItalic
        case .headerSmaller: .legacySmallHeading
        case .headerSmallerItalic: .font076emItalic
        case .header2: .legacyHeadingBold
        case .header3: .legacyHeading
        case .header4: .legacyHeading
        case .font100emSmallCaps: .legacySmallCaps
        }
    }

    private init(preset: Preset) {
        self.preset = preset
    }

    /// Retains introduction-title sizing when an inline span selects a different text style.
    func preservingSize(of inheritedFont: BibleTextFont) -> BibleTextFont {
        let isSmallerTitle: Bool
        switch inheritedFont.preset {
        case .font130em, .font130emItalic, .font130em500, .font130em500Italic, .font130em700:
            isSmallerTitle = true
        case .font160em, .font160emItalic, .font160em500, .font160em500Italic, .font160em700:
            isSmallerTitle = false
        default:
            return self
        }

        let resizedPreset: Preset
        switch preset {
        case .font100em:
            resizedPreset = isSmallerTitle ? .font130em : .font160em
        case .font100emItalic:
            resizedPreset = isSmallerTitle ? .font130emItalic : .font160emItalic
        case .font100em500:
            resizedPreset = isSmallerTitle ? .font130em500 : .font160em500
        case .font100em500Italic:
            resizedPreset = isSmallerTitle ? .font130em500Italic : .font160em500Italic
        case .font100em700:
            resizedPreset = isSmallerTitle ? .font130em700 : .font160em700
        default:
            return self
        }
        return BibleTextFont(preset: resizedPreset)
    }

    /// Creates the complete font table for the selected family and base size.
    static func fonts(familyName: String, baseSize: CGFloat) -> [BibleTextFont: Font] {
        let italicFamilyName: String

        if familyName.hasSuffix("-Regular") {
            let base = familyName.split(separator: "-").dropLast().joined(separator: "-")
            italicFamilyName = base + "-Italic"
        } else {
            italicFamilyName = familyName
        }

        func presetFont(for preset: Preset) -> Font {
            switch preset {
            case .font076emItalic: Self.font(familyName: italicFamilyName, size: baseSize * 0.76).italic()
            case .font083emItalic: Self.font(familyName: italicFamilyName, size: baseSize * 0.83).italic()
            case .font100em: Self.font(familyName: familyName, size: baseSize)
            case .font100emItalic: Self.font(familyName: italicFamilyName, size: baseSize).italic()
            case .font100em500: Self.font(familyName: familyName, size: baseSize).weight(.medium)
            case .font100em500Italic: Self.font(familyName: italicFamilyName, size: baseSize).weight(.medium).italic()
            case .font100em700: Self.font(familyName: familyName, size: baseSize).weight(.bold)
            case .font108emItalic: Self.font(familyName: italicFamilyName, size: baseSize * 1.08).italic()
            case .font117em500: Self.font(familyName: familyName, size: baseSize * 1.17).weight(.medium)
            case .font117em500Italic: Self.font(familyName: italicFamilyName, size: baseSize * 1.17).weight(.medium).italic()
            case .font117em700: Self.font(familyName: familyName, size: baseSize * 1.17).weight(.bold)
            case .font130emItalic: Self.font(familyName: italicFamilyName, size: baseSize * 1.3).italic()
            case .font160em700: Self.font(familyName: familyName, size: baseSize * 1.6).weight(.bold)
            case .footnote: Self.font(familyName: familyName, size: baseSize * 0.8)
            case .verseNumFont: Self.font(familyName: "Helvetica Neue", size: baseSize * 0.65).smallCaps()
            case .font130em: Self.font(familyName: familyName, size: baseSize * 1.3)
            case .font130em500: Self.font(familyName: familyName, size: baseSize * 1.3).weight(.medium)
            case .font130em500Italic: Self.font(familyName: italicFamilyName, size: baseSize * 1.3).weight(.medium).italic()
            case .font130em700: Self.font(familyName: familyName, size: baseSize * 1.3).weight(.bold)
            case .font160em: Self.font(familyName: familyName, size: baseSize * 1.6)
            case .font160emItalic: Self.font(familyName: italicFamilyName, size: baseSize * 1.6).italic()
            case .font160em500: Self.font(familyName: familyName, size: baseSize * 1.6).weight(.medium)
            case .font160em500Italic: Self.font(familyName: italicFamilyName, size: baseSize * 1.6).weight(.medium).italic()
            case .legacyBold: Self.font(familyName: familyName, size: baseSize).bold()
            case .legacySmallCaps: Self.font(familyName: familyName, size: baseSize).lowercaseSmallCaps()
            case .legacyHeading: Self.font(familyName: familyName, size: baseSize * 1.1)
            case .legacyHeadingBold: Self.font(familyName: familyName, size: baseSize * 1.1).weight(.bold)
            case .legacyHeadingItalic: Self.font(familyName: italicFamilyName, size: baseSize * 1.1).italic()
            case .legacySmallHeading: Self.font(familyName: familyName, size: baseSize * 0.9).weight(.medium)
            }
        }

        return Dictionary(uniqueKeysWithValues: Preset.allCases.map { preset in
            (BibleTextFont(preset: preset), presetFont(for: preset))
        })
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
