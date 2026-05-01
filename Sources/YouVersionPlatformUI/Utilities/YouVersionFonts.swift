import SwiftUI

public enum YouVersionFonts {
    public static let systemMedium = Font.system(size: 18, weight: .medium)
    public static let headerMedium = Font.system(size: 20, weight: .bold)
    public static let headerSmall = Font.system(size: 16, weight: .bold)
    public static let eyebrowSmall = Font.system(size: 11, weight: .bold)
    public static let labelMedium = Font.system(size: 13, weight: .medium)
    public static let labelSmall = Font.system(size: 11, weight: .medium)
    public static let captionsLarge = Font.system(size: 13)
    public static let captionsSmall = Font.system(size: 11)

    @available(*, deprecated, renamed: "systemMedium")
    public static var fontSystemM: Font { systemMedium }

    @available(*, deprecated, renamed: "headerMedium")
    public static var fontHeaderM: Font { headerMedium }

    @available(*, deprecated, renamed: "headerSmall")
    public static var fontHeaderS: Font { headerSmall }

    @available(*, deprecated, renamed: "eyebrowSmall")
    public static var fontEyebrowS: Font { eyebrowSmall }

    @available(*, deprecated, renamed: "labelMedium")
    public static var fontLabelM: Font { labelMedium }

    @available(*, deprecated, renamed: "labelSmall")
    public static var fontLabelS: Font { labelSmall }

    @available(*, deprecated, renamed: "captionsLarge")
    public static var fontCaptionsL: Font { captionsLarge }

    @available(*, deprecated, renamed: "captionsSmall")
    public static var fontCaptionsS: Font { captionsSmall }

    /// For YouVersion uses of the Untitled font, use Baskerville as a fallback.
    public static func preferredBibleTextFont(size: CGFloat) -> Font {
        Font.custom("Baskerville", size: size)
    }
}
