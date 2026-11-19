import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import YouVersionPlatformUI

@MainActor
@Suite struct BibleTextOptionsTests {
    private struct ThemeProvider: ReaderThemeProviding {
        let colorTheme: ReaderTheme?
    }

    @Test(arguments: ReaderTheme.allThemes)
    func readerWordsOfChristColorFollowsReaderTheme(theme: ReaderTheme) {
        let expectedHex = theme.colorScheme == .dark ? "E4BFC2" : "94000C"
        #expect(ThemeProvider(colorTheme: theme).readerWordsOfChristColor.hexString == expectedHex)
    }

    @Test func readerWordsOfChristColorWithoutThemeIsLight() {
        #expect(ThemeProvider(colorTheme: nil).readerWordsOfChristColor.hexString == "94000C")
    }

#if canImport(UIKit)
    // The SDK picks colors from the reader theme, not from the system appearance.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func defaultWordsOfChristColorIgnoresSystemAppearance(style: UIUserInterfaceStyle) {
        let color = UIColor(BibleTextOptions().wordsOfChristColor)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        #expect(Color(uiColor: color).hexString == "94000C")
    }
#endif
}
