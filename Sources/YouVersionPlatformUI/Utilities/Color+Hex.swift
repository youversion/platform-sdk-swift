import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: Double
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = (
                Double((int >> 8) * 17) / 255,
                Double((int >> 4 & 0xF) * 17) / 255,
                Double((int & 0xF) * 17) / 255,
                1.0
            )
        case 6: // RGB (24-bit)
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255,
                1.0
            )
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255,
                Double((int >> 24) & 0xFF) / 255
            )
        default:
            (r, g, b, a) = (0, 0, 0, 1)
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// returns e.g. "DDAAFF" indicating RGB. Conversion maybe be impossible and if so this will return nil.
    var hexString: String? {
#if canImport(UIKit)
        let uiColor = UIColor(self)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())

        return String(format: "%02X%02X%02X", r, g, b)
#else
        return nil
#endif
    }
}

extension Color {
    private static let redLumaWeight: Float = 0.299
    private static let greenLumaWeight: Float = 0.587
    private static let blueLumaWeight: Float = 0.114
    private static let darkLumaThreshold: Float = 0.5

    /// Returns the 24-bit RGB value of a hex color string, ignoring any alpha byte.
    ///
    /// Accepts `RGB`, `RRGGBB`, and `AARRGGBB`, each with or without a leading `#`.
    /// Use it to compare colors saved in different formats.
    ///
    /// - Parameter hex: The hex color string to read.
    /// - Returns: The color as `0xRRGGBB`, or `nil` if `hex` isn't one of the accepted formats.
    package static func rgbValue(fromHex hex: String) -> UInt32? {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        switch digits.count {
        case 3:
            let red = (value >> 8) & 0xF
            let green = (value >> 4) & 0xF
            let blue = value & 0xF
            return (red * 0x11) << 16 | (green * 0x11) << 8 | blue * 0x11
        case 6:
            return value
        case 8:
            return value & 0xFFFFFF
        default:
            return nil
        }
    }

    /// Whether the color is dark enough that text over it should be white.
    ///
    /// Translucent colors are blended over a white page before their luma is measured.
    package var isDarkHighlight: Bool {
        let resolved = resolve(in: EnvironmentValues())
        let opacity = resolved.opacity
        func overWhitePage(_ channel: Float) -> Float {
            opacity * channel + 1 - opacity
        }
        let luma = Self.redLumaWeight * overWhitePage(resolved.red)
            + Self.greenLumaWeight * overWhitePage(resolved.green)
            + Self.blueLumaWeight * overWhitePage(resolved.blue)
        return luma < Self.darkLumaThreshold
    }
}
