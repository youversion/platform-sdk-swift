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
    func lightHighlightHexIsNotDark(hex: String) {
        #expect(Color.isDarkHighlightHex(hex) == false)
    }

    @Test(arguments: ["000000", "#121212", "5c2d91", "1e3a8a", "#000", "FF000000", "C0000000"])
    func darkHighlightHexIsDark(hex: String) {
        #expect(Color.isDarkHighlightHex(hex) == true)
    }

    @Test(arguments: ["", "ff", "zzzzzz", "12345"])
    func malformedHighlightHexIsNotDark(hex: String) {
        #expect(Color.isDarkHighlightHex(hex) == false)
    }

#if canImport(UIKit)
    @Test
    func argbHexStringKeepsAlpha() {
        #expect(Color(hex: "#40000000").argbHexString == "40000000")
        #expect(Color(hex: "DDAAFF").argbHexString == "FFDDAAFF")
    }
#endif

    @Test
    func rgbHexNormalizesEveryFormatColorHexReads() {
        #expect(Color.rgbHex("#FA3") == "ffaa33")
        #expect(Color.rgbHex("DDAAFF") == "ddaaff")
        #expect(Color.rgbHex("#80DDAAFF") == "ddaaff")
        #expect(Color.rgbHex("#") == nil)
        #expect(Color.rgbHex("zzzzzz") == nil)
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
