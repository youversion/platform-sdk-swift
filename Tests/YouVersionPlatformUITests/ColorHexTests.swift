import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import YouVersionPlatformUI

@Suite struct ColorHexTests {
    @Test
    func threeDigitHexExpandsColorComponents() throws {
        guard let components = try colorComponents(for: Color(hex: "#FA3")) else {
            return
        }

        #expect(components.red.isApproximatelyEqual(to: 1.0) == true)
        #expect(components.green.isApproximatelyEqual(to: 170.0 / 255.0) == true)
        #expect(components.blue.isApproximatelyEqual(to: 51.0 / 255.0) == true)
        #expect(components.alpha.isApproximatelyEqual(to: 1.0) == true)
    }

    @Test
    func eightDigitHexReadsArgbColorComponents() throws {
        guard let components = try colorComponents(for: Color(hex: "#80DDAAFF")) else {
            return
        }

        #expect(components.red.isApproximatelyEqual(to: 221.0 / 255.0) == true)
        #expect(components.green.isApproximatelyEqual(to: 170.0 / 255.0) == true)
        #expect(components.blue.isApproximatelyEqual(to: 255.0 / 255.0) == true)
        #expect(components.alpha.isApproximatelyEqual(to: 128.0 / 255.0) == true)
    }

    @Test(arguments: ["ffec5b", "b4ffc1", "bbf4ff", "ffdca7", "ffcff8", "dfdcff", "#FFFFFF", "fff", "80DDAAFF", "10000000", "#40000000"])
    func lightHighlightIsNotDark(hex: String) {
        #expect(Color(hex: hex).isDarkHighlight == false)
    }

    @Test(arguments: ["000000", "#121212", "5c2d91", "1e3a8a", "#000", "FF000000", "C0000000"])
    func darkHighlightIsDark(hex: String) {
        #expect(Color(hex: hex).isDarkHighlight == true)
    }

    @Test
    func rgbValueReadsEveryFormatColorHexReads() {
        #expect(Color.rgbValue(fromHex: "#FA3") == 0xFFAA33)
        #expect(Color.rgbValue(fromHex: "DDAAFF") == 0xDDAAFF)
        #expect(Color.rgbValue(fromHex: "ddaaff") == 0xDDAAFF)
        #expect(Color.rgbValue(fromHex: "#80DDAAFF") == 0xDDAAFF)
        #expect(Color.rgbValue(fromHex: "#") == nil)
        #expect(Color.rgbValue(fromHex: "zzzzzz") == nil)
        #expect(Color.rgbValue(fromHex: "12345") == nil)
    }

    private func colorComponents(for color: Color) throws -> ColorComponents? {
#if canImport(UIKit)
        let color = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        try #require(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))

        return ColorComponents(red: red, green: green, blue: blue, alpha: alpha)
#else
        return nil
#endif
    }
}

private struct ColorComponents {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

private extension CGFloat {
    func isApproximatelyEqual(to expectedValue: CGFloat) -> Bool {
        abs(self - expectedValue) < 0.0001
    }
}
