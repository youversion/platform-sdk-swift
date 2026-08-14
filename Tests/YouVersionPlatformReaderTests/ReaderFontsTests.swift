import CoreText
import Foundation
import SwiftUI
import Testing
@testable import YouVersionPlatformReader
@testable import YouVersionPlatformUI

@MainActor
@Suite(.serialized)
struct ReaderFontsTests {
    @Test
    func preferredBibleTextFontChangesAfterReaderFontsAreInstalled() throws {
        let fontURLs = try #require(
            Bundle.YouVersionReaderBundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil)
        )

        for fontURL in fontURLs {
            CTFontManagerUnregisterFontsForURL(fontURL as CFURL, .process, nil)
        }

        let fallbackFontDescription = debugDescription(of: YouVersionFonts.preferredBibleTextFont(size: 20))
        #expect(fallbackFontDescription.contains("Baskerville"))

        ReaderFonts.installFonts()

        let readerFontDescription = debugDescription(of: YouVersionFonts.preferredBibleTextFont(size: 20))
        #expect(readerFontDescription.contains("Untitled Serif"))
    }

    @Test
    func isPermittedFontAcceptsSuggestedAndOtherFamilies() {
        #expect(ReaderFonts.isPermittedFont("Untitled Serif"))
        #expect(ReaderFonts.isPermittedFont("New York"))
        #expect(ReaderFonts.isPermittedFont("San Francisco"))
        #expect(ReaderFonts.isPermittedFont("Georgia"))
        #expect(ReaderFonts.isPermittedFont("Arial"))
        #expect(ReaderFonts.isPermittedFont("Times New Roman"))
    }

    @Test
    func isPermittedFontRejectsUnknownFamilies() {
        #expect(ReaderFonts.isPermittedFont("") == false)
        #expect(ReaderFonts.isPermittedFont("Definitely Not A Reader Font") == false)
        #expect(ReaderFonts.isPermittedFont("georgia") == false)
    }

    @Test
    func displayFontUsesSystemProviderForSystemFontFamilies() {
        let sanFranciscoDescription = debugDescription(
            of: ReaderFonts.displayFont(familyName: "San Francisco", size: 20)
        )
        #expect(sanFranciscoDescription.contains("SwiftUI.Font.SystemProvider"))
        #expect(sanFranciscoDescription.contains("size: 20.0"))
        #expect(sanFranciscoDescription.contains("design: nil"))
        #expect(sanFranciscoDescription.contains("SwiftUI.Font.NamedProvider") == false)

        let newYorkDescription = debugDescription(
            of: ReaderFonts.displayFont(familyName: "New York", size: 20)
        )
        #expect(newYorkDescription.contains("SwiftUI.Font.SystemProvider"))
        #expect(newYorkDescription.contains("size: 20.0"))
        #expect(newYorkDescription.contains("SwiftUI.Font.Design.serif"))
        #expect(newYorkDescription.contains("SwiftUI.Font.NamedProvider") == false)
    }

    @Test
    func nextSmallerSizeReturnsNearestSmallerAvailableSize() {
        #expect(ReaderFonts.nextSmallerSize(currentSize: 27) == 24)
        #expect(ReaderFonts.nextSmallerSize(currentSize: 22) == 21)
        #expect(ReaderFonts.nextSmallerSize(currentSize: 9) == nil)
        #expect(ReaderFonts.nextSmallerSize(currentSize: 1) == nil)
    }

    @Test
    func nextLargerSizeReturnsNearestLargerAvailableSize() {
        #expect(ReaderFonts.nextLargerSize(currentSize: 9) == 12)
        #expect(ReaderFonts.nextLargerSize(currentSize: 22) == 24)
        #expect(ReaderFonts.nextLargerSize(currentSize: 27) == nil)
        #expect(ReaderFonts.nextLargerSize(currentSize: 100) == nil)
    }

    @Test
    func nextLineSpacingCyclesThroughAvailableSpacing() {
        #expect(ReaderFonts.nextLineSpacing(currentSpacing: ReaderFonts.lineSpacingOptions[0]) == ReaderFonts.lineSpacingOptions[1])
        #expect(ReaderFonts.nextLineSpacing(currentSpacing: ReaderFonts.lineSpacingOptions[1]) == ReaderFonts.lineSpacingOptions[2])
        #expect(ReaderFonts.nextLineSpacing(currentSpacing: ReaderFonts.lineSpacingOptions.last!) == ReaderFonts.lineSpacingOptions[0])
        #expect(ReaderFonts.nextLineSpacing(currentSpacing: 999) == ReaderFonts.lineSpacingOptions.first)
    }

    @Test
    func nonFiniteStoredLineSpacingFallsBackToDefault() {
        #expect(ReaderFonts.lineSpacing(forStoredValue: .nan) == ReaderFonts.defaultLineSpacing)
        #expect(ReaderFonts.lineSpacing(forStoredValue: .infinity) == ReaderFonts.defaultLineSpacing)
        #expect(ReaderFonts.lineSpacing(forStoredValue: -.infinity) == ReaderFonts.defaultLineSpacing)
    }
}

private func debugDescription(of font: Font) -> String {
    var output = ""
    dump(font, to: &output)
    return output
}
