enum BibleReaderAccessibilityIdentifiers {
    enum Header {
        static let menuButton = "bibleReader.header.menuButton"
        static let fontSettingsMenuButton = "bibleReader.header.fontSettingsMenuButton"
        static let bookAndChapterPickerButton = "bibleReader.header.bookAndChapterPickerButton"
        static let versionPickerButton = "bibleReader.header.versionPickerButton"
    }

    enum BookChapterPicker {
        static let sheet = "bibleReader.bookAndChapterPicker.sheet"
        static let cancelButton = "bibleReader.bookAndChapterPicker.cancelButton"

        static func bookButton(_ bookCode: String) -> String {
            "bibleReader.bookAndChapterPicker.bookButton.\(bookCode)"
        }

        static func introButton(_ bookCode: String) -> String {
            "bibleReader.bookAndChapterPicker.introButton.\(bookCode)"
        }

        static func chapterButton(bookCode: String, chapter: Int) -> String {
            "bibleReader.bookAndChapterPicker.chapterButton.\(bookCode).\(chapter)"
        }
    }

    enum FontSettings {
        static let smallerFontButton = "bibleReader.fontSettings.smallerFontButton"
        static let biggerFontButton = "bibleReader.fontSettings.biggerFontButton"
        static let fontFamilyButton = "bibleReader.fontSettings.fontFamilyButton"
        static let lineSpacingButton = "bibleReader.fontSettings.lineSpacingButton"

        static func themeButton(_ themeID: Int) -> String {
            "bibleReader.fontSettings.themeButton.\(themeID)"
        }
    }

    enum FontList {
        static let backButton = "bibleReader.fontList.backButton"

        static func fontButton(family: String) -> String {
            "bibleReader.fontList.fontButton.\(family)"
        }
    }
}
