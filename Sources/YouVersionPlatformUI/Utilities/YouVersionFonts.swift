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

    /// For YouVersion uses of the Untitled font, use Baskerville as a fallback.
    public static func preferredBibleTextFont(size: CGFloat) -> Font {
        Font.custom("Baskerville", size: size)
    }
}
