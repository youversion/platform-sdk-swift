import CoreText
import Foundation
import SwiftUI
import YouVersionPlatformCore

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
            if let cfURL = bundle.url(forResource: name, withExtension: "ttf") as CFURL? {
                CTFontManagerRegisterFontsForURL(cfURL, CTFontManagerScope.process, nil)
            } else {
                YouVersionPlatformLogger.notice("missing font: \(name)", category: "Fonts")
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

    static func isPermittedFont(_ family: String?) -> Bool {
        guard let family else {
            return false
        }
        return suggestedFamilies.contains(family) || otherFamilies.contains(family)
    }

    // MARK: - Font Sizes and Spacing

    static let availableSizes = [9, 12, 15, 18, 21, 24, 27]
    static let lineSpacingOptions = [6, 12, 18]

    // MARK: - Default Values

    static let defaultFontFamily = "Untitled Serif"
    static let defaultFontSize: CGFloat = 21
    static let defaultLineSpacing: CGFloat = 12

    // MARK: - Utility Functions

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
