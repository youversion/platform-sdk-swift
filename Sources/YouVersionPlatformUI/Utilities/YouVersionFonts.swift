import SwiftUI

public enum YouVersionFonts {
    public static let fontSystemM = Font.system(size: 18, weight: .medium)
    public static let fontHeaderM = Font.system(size: 20, weight: .bold)
    public static let fontHeaderS = Font.system(size: 16, weight: .bold)
    public static let fontEyebrowS = Font.system(size: 11, weight: .bold)
    public static let fontLabelM = Font.system(size: 13, weight: .medium)
    public static let fontLabelS = Font.system(size: 11, weight: .medium)
    public static let fontCaptionsL = Font.system(size: 13)
    public static let fontCaptionsS = Font.system(size: 11)

    /// For YouVersion uses of the Untitled font, use Baskerville as a fallback.
    public static func preferredBibleTextFont(size: CGFloat) -> Font {
        Font.custom("Baskerville", size: size)
    }
}
