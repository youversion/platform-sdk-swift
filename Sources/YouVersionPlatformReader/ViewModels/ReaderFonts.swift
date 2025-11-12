import CoreText
import Foundation
import SwiftUI

public enum ReaderFonts {

    // MARK: - Font Installation

    private nonisolated(unsafe) static var fontsNeedInstallation = true

    public static func installFontsIfNeeded() {
        guard fontsNeedInstallation else {
            return
        }
        fontsNeedInstallation = false

        let fontNames = [
            "UntitledSerifApp-Medium",
            "UntitledSerifApp-MediumItalic",
            "UntitledSerifApp-Regular",
            "UntitledSerifApp-RegularItalic",
            "UntitledSerifApp-Bold",
            "UntitledSerifApp-BoldItalic"
        ]
        let bundle = Bundle.YouVersionReaderBundle
        for name in fontNames {
            if let url = bundle.url(forResource: name, withExtension: "ttf"),
               let fontDataProvider = CGDataProvider(url: url as CFURL),
               let font = CGFont(fontDataProvider) {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterGraphicsFont(font, &error)
            } else {
                print("missing font: \(name)")
            }
        }
    }

    // MARK: - Font Families

    static let suggestedFamilies = [
        "Untitled Serif",
        "Avenir Next",
        // New York
        // San Francisco
        // Gentium Plus
        "Baskerville", "Georgia", "Helvetica Neue", "Hoefler Text", "Verdana"
        // OpenDyslexic
    ]

    // TODO: pull these from our API, and check that they're present on the device.
    // The list might well vary depending on the current Bible language.
    static let otherFamilies = [
        "Academy Engraved LET",
        "American Typewriter",
        "Apple SD Gothic Neo",
        "Arial",
        "Bodoni 72",
        "Bodoni 72 Oldstyle",
        "Charter",
        "Cochin",
        "Courier New",
        "Didot",
        "Futura",
        "Galvji",
        "Gill Sans",
        "Grantha Sangam MN",
        "Helvetica",
        "Impact",
        "Kefa",
        "Menlo",
        "Mukta Mahee",
        "Optima",
        "Palatino",
        "PingFang MO",
        "Rockwell",
        "STIX Two Math",
        "STIX Two Text",
        "Times New Roman",
        "Trebuchet MS"
    ]

    // MARK: - Font Sizes and Spacing

    static let availableSizes = [9, 12, 15, 18, 21, 24]
    static let lineSpacingOptions = [6, 12, 18]

    // MARK: - Default Values

    static let defaultFontFamily = "Untitled Serif"
    static let defaultFontSize: CGFloat = 21
    static let defaultLineSpacing: CGFloat = 12

    // MARK: - UI Fonts

    static let fontSystemM = Font.system(size: 18, weight: .medium)
    static let fontHeaderM = Font.system(size: 20, weight: .bold)
    static let fontHeaderS = Font.system(size: 16, weight: .medium)
    static let fontEyebrowS = Font.system(size: 11, weight: .bold)
    static let fontLabelM = Font.system(size: 13, weight: .medium)
    static let fontCaptionsL = Font.system(size: 13)
    static let fontCaptionsS = Font.system(size: 11)

    // MARK: - Utility Functions

    /// For YouVersion uses of the Untitled font, we will use Baskerville as a fallback
    static func preferredBibleTextFont(size: CGFloat) -> Font {
        Font.custom("Baskerville", size: size)
    }

    static func nextSmallerSize(currentSize: CGFloat) -> CGFloat? {
        let currentSizeInt = Int(currentSize)
        return availableSizes.filter({ $0 < currentSizeInt }).max().map(CGFloat.init)
    }

    static func nextLargerSize(currentSize: CGFloat) -> CGFloat? {
        let currentSizeInt = Int(currentSize)
        return availableSizes.filter({ $0 > currentSizeInt }).min().map(CGFloat.init)
    }

    static func nextLineSpacing(currentSpacing: CGFloat) -> CGFloat {
        if let nextBigger = lineSpacingOptions.filter({ CGFloat($0) > currentSpacing }).min() {
            CGFloat(nextBigger)
        } else {
            CGFloat(lineSpacingOptions.min()!)
        }
    }
}
