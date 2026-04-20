import CoreText
import Foundation
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

@MainActor
@Observable
final class BibleReaderViewModel {
    private let userDefaultsKeyForBibleReference = "bible-reader-view--reference"
    private let userDefaultsKeyForBibleDisplayIntro = "bible-reader-view--displayintro"
    private let userDefaultsKeyForReaderSettings = "bible-reader-view--readersettings"
    var reference: BibleReference {
        didSet {
            if let data = try? JSONEncoder().encode(reference) {
                UserDefaults.standard.set(data, forKey: userDefaultsKeyForBibleReference)
            }
        }
    }
    var showBookIntro: Bool {
        didSet {
            UserDefaults.standard.set(showBookIntro, forKey: userDefaultsKeyForBibleDisplayIntro)
        }
    }
    let highlightsViewModel: BibleHighlightsViewModel
    var versionsViewModel: BibleVersionsViewModel
    var version: BibleVersion?
    let onVerseTap: ((BibleReference) -> Void)?
    let verseSelectionStyle: VerseSelectionStyle

    init(
        reference: BibleReference? = nil,
        highlightsViewModel: BibleHighlightsViewModel? = nil,
        verseSelectionStyle: VerseSelectionStyle = .solid,
        versionsViewModel: BibleVersionsViewModel? = nil,
        onVerseTap: ((BibleReference) -> Void)? = nil
    ) {
        if let reference {
            self.reference = reference
            self.showBookIntro = false
        } else {
            if let data = UserDefaults.standard.data(forKey: userDefaultsKeyForBibleReference),
               let savedValue = try? JSONDecoder().decode(BibleReference.self, from: data) {
                self.reference = savedValue
                self.showBookIntro = UserDefaults.standard.bool(forKey: userDefaultsKeyForBibleDisplayIntro)
            } else {
                // no specified or saved version, so, pick a downloaded one, else a safe default.
                let downloads = VersionDownloadCache.downloadedVersions
                let versionId = reference?.versionId ?? downloads.first ?? 3034
                self.reference = BibleReference(versionId: versionId, bookUSFM: "JHN", chapter: 1)
                self.showBookIntro = false
            }
        }

        self.onVerseTap = onVerseTap
        self.verseSelectionStyle = verseSelectionStyle
        self.highlightsViewModel = highlightsViewModel ?? BibleHighlightsViewModel()
        self.versionsViewModel = versionsViewModel ?? BibleVersionsViewModel { _ in }
        self.versionsViewModel.onVersionChange = { [weak self] version in
            self?.onVersionChange(version: version)
        }
        self.versionsViewModel.onSignInRequired = { [weak self] in
            self?.onSignInRequired()
        }

        loadUserSettingsFromStorage()  // will overwrite colorTheme, fontFamily, etc.
        self.versionsViewModel.colorTheme = colorTheme

        ReaderFonts.installFontsIfNeeded()
    }
    
    func onVersionChange(version: BibleVersion) {
        self.version = version
        self.reference = BibleReference(versionId: version.id, bookUSFM: reference.bookUSFM, chapter: reference.chapter)
        Task {
            await onHeaderSelectionChange(reference, showIntro: false)
        }
    }
    
    func onSignInRequired() {
        startSignInFlow = true
    }

    func loadUserSettingsFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKeyForReaderSettings),
              let savedValue = try? JSONDecoder().decode(ReaderSettings.self, from: data) else {
            // missing or corrupted settings; use the defaults.
            return
        }
        fontFamily = ReaderFonts.isPermittedFont(savedValue.fontFamily) ? savedValue.fontFamily : ReaderFonts.defaultFontFamily
        fontSize = savedValue.fontSize ?? ReaderFonts.defaultFontSize
        lineSpacing = savedValue.lineSpacing ?? ReaderFonts.defaultLineSpacing
        colorTheme = ReaderTheme.theme(withId: savedValue.colorTheme)
    }

    func saveUserSettingsToStorage() {
        let settings = ReaderSettings(
            fontFamily: fontFamily,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            colorTheme: colorTheme?.id ?? ReaderTheme.theme().id
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKeyForReaderSettings)
        }
    }

    private class ReaderSettings: Codable {
        let fontFamily: String?
        let fontSize: CGFloat?
        let lineSpacing: CGFloat?
        let colorTheme: Int?
        init(fontFamily: String?, fontSize: CGFloat?, lineSpacing: CGFloat?, colorTheme: Int?) {
            self.fontFamily = fontFamily
            self.fontSize = fontSize
            self.lineSpacing = lineSpacing
            self.colorTheme = colorTheme
        }
    }

    // MARK: - UI state of the Reader itself
    var showChrome = true
    var lastScrollOffset: CGFloat = 0
    var scrollToTop = false
    var isChangingChapter = false
    var showingSignInSheet = false
    var showingFontSettings = false
    var showingFontList = false
    var showingFootnotes = false
    var showingIntroFootnoteSheet = false
    var showingVerseActionsDrawer = false
    var isReduceMotionEnabled = false
    var verseActionsDrawerAnimation: Animation {
        isReduceMotionEnabled ? .easeInOut(duration: 0.2) : .smooth(duration: 0.3)
    }
    var selectedVerses: Set<BibleReference> = []

    var showingBookPicker = false
    private var showingChapterPicker = false
    var headerExpandedBookCode: String?
    var footnotesToDisplay: [BibleFootnote] = []

    let readerMaxWidth = CGFloat(700)  // of the reader and the verse action drawer, maybe others

    // MARK: - Font settings

    private var fontFamily: String? = ReaderFonts.defaultFontFamily
    private var fontSize: CGFloat? = ReaderFonts.defaultFontSize
    private var lineSpacing = ReaderFonts.defaultLineSpacing

    var textOptions: BibleTextOptions {
        ReaderFonts.installFontsIfNeeded()
        let ourFontSize = fontSize ?? 18
        return BibleTextOptions(
            fontFamily: fontFamily ?? "Georgia",
            fontSize: ourFontSize,
            // TODO: maybe have one of these spacings be a delta added to the other:
            lineSpacing: lineSpacing,
            paragraphSpacing: lineSpacing,
            textColor: readerTextPrimaryColor,
            verseNumColor: readerVerseNumColor,
            wocColor: readerWordsOfChristColor,
            footnoteMode: .image,
            footnoteMarker: nil,
            verseSelectionStyle: verseSelectionStyle
        )
    }

    func openFontSettings() {
        showingFontSettings = true
    }

    func handleSmallerFontTap() {
        if let newSize = ReaderFonts.nextSmallerSize(currentSize: textOptions.fontSize) {
            setFont(size: newSize)
        }
    }

    func handleBiggerFontTap() {
        if let newSize = ReaderFonts.nextLargerSize(currentSize: textOptions.fontSize) {
            setFont(size: newSize)
        }
    }

    func setFont(family: String? = nil, size: CGFloat? = nil) {
        if let family {
            fontFamily = family
        }
        if let size {
            fontSize = size
        }
        saveUserSettingsToStorage()
    }

    func selectNextLineSpacing() {
        lineSpacing = ReaderFonts.nextLineSpacing(currentSpacing: lineSpacing)
        saveUserSettingsToStorage()
    }

    // MARK: Colors

    var colorTheme: ReaderTheme? = ReaderTheme.theme()

    func setColorTheme(_ theme: ReaderTheme) {
        colorTheme = theme
        versionsViewModel.colorTheme = theme
        saveUserSettingsToStorage()
    }

    // MARK: - Sign In & Out

    var startSignInFlow = false
    private(set) var isSignedIn = false
    var showSignOutConfirmation = false

    func updateSignInState() {
        Task {
            let hasValidToken = await YouVersionAPI.hasValidToken()
            await MainActor.run {
                isSignedIn = hasValidToken
            }
        }
    }

    func signIn() {
        if YouVersionAPI.isSignedIn {
            return
        }
        startSignInFlow = true
    }

    func signOut() {
        showSignOutConfirmation = true
    }

    func confirmSignOut() {
        YouVersionAPI.Users.signOut()
        highlightsViewModel.reset()
        isSignedIn = false
    }
}
