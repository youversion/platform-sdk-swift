public enum BibleReaderAccessibilityIdentifiers {
    public enum Header {
        public static let menuButton = "bibleReader.header.menuButton"
        public static let fontSettingsMenuButton = "bibleReader.header.fontSettingsMenuButton"
        public static let bookAndChapterPickerButton = "bibleReader.header.bookAndChapterPickerButton"
        public static let versionPickerButton = "bibleReader.header.versionPickerButton"
    }

    public enum BookChapterPicker {
        public static let sheet = "bibleReader.bookAndChapterPicker.sheet"
        public static let cancelButton = "bibleReader.bookAndChapterPicker.cancelButton"

        public static func bookButton(_ bookCode: String) -> String {
            "bibleReader.bookAndChapterPicker.bookButton.\(bookCode)"
        }

        public static func introButton(_ bookCode: String) -> String {
            "bibleReader.bookAndChapterPicker.introButton.\(bookCode)"
        }

        public static func chapterButton(bookCode: String, chapter: Int) -> String {
            "bibleReader.bookAndChapterPicker.chapterButton.\(bookCode).\(chapter)"
        }
    }

    public enum FontSettings {
        public static let smallerFontButton = "bibleReader.fontSettings.smallerFontButton"
        public static let biggerFontButton = "bibleReader.fontSettings.biggerFontButton"
        public static let fontFamilyButton = "bibleReader.fontSettings.fontFamilyButton"
        public static let lineSpacingButton = "bibleReader.fontSettings.lineSpacingButton"

        public static func themeButton(_ themeID: Int) -> String {
            "bibleReader.fontSettings.themeButton.\(themeID)"
        }
    }

    public enum FontList {
        public static let backButton = "bibleReader.fontList.backButton"

        public static func fontButton(family: String) -> String {
            "bibleReader.fontList.fontButton.\(family)"
        }
    }
}
