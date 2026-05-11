import Testing
import YouVersionPlatformReader

struct BibleReaderAccessibilityIdentifiersTests {
    @Test
    func headerIdentifiersAreAccessible() {
        #expect(BibleReaderAccessibilityIdentifiers.Header.menuButton == "bibleReader.header.menuButton")
        #expect(BibleReaderAccessibilityIdentifiers.Header.fontSettingsMenuButton == "bibleReader.header.fontSettingsMenuButton")
        #expect(BibleReaderAccessibilityIdentifiers.Header.bookAndChapterPickerButton == "bibleReader.header.bookAndChapterPickerButton")
        #expect(BibleReaderAccessibilityIdentifiers.Header.versionPickerButton == "bibleReader.header.versionPickerButton")
    }

    @Test
    func bookChapterPickerIdentifiersAreAccessible() {
        #expect(BibleReaderAccessibilityIdentifiers.BookChapterPicker.sheet == "bibleReader.bookAndChapterPicker.sheet")
        #expect(BibleReaderAccessibilityIdentifiers.BookChapterPicker.cancelButton == "bibleReader.bookAndChapterPicker.cancelButton")
        #expect(BibleReaderAccessibilityIdentifiers.BookChapterPicker.bookButton("GEN") == "bibleReader.bookAndChapterPicker.bookButton.GEN")
        #expect(BibleReaderAccessibilityIdentifiers.BookChapterPicker.introButton("GEN") == "bibleReader.bookAndChapterPicker.introButton.GEN")
        #expect(BibleReaderAccessibilityIdentifiers.BookChapterPicker.chapterButton(bookCode: "GEN", chapter: 1) == "bibleReader.bookAndChapterPicker.chapterButton.GEN.1")
    }

    @Test
    func fontSettingsIdentifiersAreAccessible() {
        #expect(BibleReaderAccessibilityIdentifiers.FontSettings.smallerFontButton == "bibleReader.fontSettings.smallerFontButton")
        #expect(BibleReaderAccessibilityIdentifiers.FontSettings.biggerFontButton == "bibleReader.fontSettings.biggerFontButton")
        #expect(BibleReaderAccessibilityIdentifiers.FontSettings.fontFamilyButton == "bibleReader.fontSettings.fontFamilyButton")
        #expect(BibleReaderAccessibilityIdentifiers.FontSettings.lineSpacingButton == "bibleReader.fontSettings.lineSpacingButton")
        #expect(BibleReaderAccessibilityIdentifiers.FontSettings.themeButton(1) == "bibleReader.fontSettings.themeButton.1")
    }

    @Test
    func fontListIdentifiersAreAccessible() {
        #expect(BibleReaderAccessibilityIdentifiers.FontList.backButton == "bibleReader.fontList.backButton")
        #expect(BibleReaderAccessibilityIdentifiers.FontList.fontButton(family: "Georgia") == "bibleReader.fontList.fontButton.Georgia")
    }
}
