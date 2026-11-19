import SwiftUI
import Testing
@testable import YouVersionPlatformUI

@MainActor
@Suite struct BibleTextOptionsTests {
    private struct ThemeProvider: ReaderThemeProviding {
        let colorTheme: ReaderTheme?
    }

    @Test(arguments: ReaderTheme.allThemes)
    func readerWordsOfChristColorFollowsReaderTheme(theme: ReaderTheme) {
        let expected = theme.colorScheme == .dark ? Color(hex: "#E4BFC2") : Color(hex: "#94000C")
        #expect(ThemeProvider(colorTheme: theme).readerWordsOfChristColor == expected)
    }

    @Test func readerWordsOfChristColorWithoutThemeIsLight() {
        #expect(ThemeProvider(colorTheme: nil).readerWordsOfChristColor == Color(hex: "#94000C"))
    }

    // A fixed color: the SDK picks colors from the reader theme, not from the system appearance.
    @Test func defaultWordsOfChristColorIsLightThemeRed() {
        #expect(BibleTextOptions().wordsOfChristColor == Color(hex: "#94000C"))
    }
}
