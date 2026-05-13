import CoreText
import Foundation
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

@MainActor
@Observable
final class BibleReaderViewModel: ReaderThemeProviding {
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
    let versionsViewModel: BibleVersionsViewModel
    var version: BibleVersion? { versionsViewModel.currentVersion }
    let onVerseTap: ((BibleReference) -> VerseTapResponse)?
    let onNoteIndicatorTap: ((BibleReference) -> Void)?
    let onReferenceChange: ((BibleReference) -> Void)?
    let onChapterComplete: ((BibleReference) -> Void)?
    let verseSelectionStyle: VerseSelectionStyle
    let audioActiveIndicatorColor: Color?
    private let authentication: BibleReaderAuthentication
    var scrollViewHeight: CGFloat = 0
    var contentHeight: CGFloat = 0
    /// The contentHeight reported by the previous geometry event for the
    /// current chapter. Used to detect when layout has settled: chapter
    /// completion only fires once contentHeight matches across two events,
    /// so the brief initial layout pass (small `blocks: []` placeholder
    /// before the chapter text loads) can't spuriously satisfy the bottom-
    /// reached check.
    var previousContentHeight: CGFloat = 0
    var hasNotifiedChapterComplete = false

    // MARK: - UI state of the Reader itself
    var showChrome = true
    var lastScrollOffset: CGFloat = 0
    var scrollToTop = false
    var isChangingChapter = false {
        didSet {
            // When a chapter-change finishes, re-evaluate using cached geometry
            // so short chapters reached via prev/next still fire onChapterComplete
            // without requiring the user to scroll.
            if oldValue && !isChangingChapter {
                evaluateChapterCompleteFromCachedGeometry()
            }
        }
    }
    var showingSignInSheet = false
    var showingFontSettings = false
    var showingFontList = false // swiftlint:disable:this collection_suffix_property
    var showingFootnotes = false
    var showingIntroFootnoteSheet = false
    var showingVerseActionsDrawer = false
    var isReduceMotionEnabled = false
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

    // MARK: - Colors

    private(set) var colorTheme: ReaderTheme? = ReaderTheme.theme()

    // MARK: - Sign In & Out

    var startSignInFlow = false
    private(set) var isSignedIn: Bool
    var showSignOutConfirmation = false

    init(
        reference: BibleReference? = nil,
        highlightsViewModel: BibleHighlightsViewModel? = nil,
        verseSelectionStyle: VerseSelectionStyle = .solid,
        versionsViewModel: BibleVersionsViewModel? = nil,
        audioActiveIndicatorColor: Color? = nil,
        onVerseTap: ((BibleReference) -> VerseTapResponse)? = nil,
        onNoteIndicatorTap: ((BibleReference) -> Void)? = nil,
        onReferenceChange: ((BibleReference) -> Void)? = nil,
        onChapterComplete: ((BibleReference) -> Void)? = nil,
        authentication: BibleReaderAuthentication? = nil
    ) {
        let authentication = authentication ?? .default
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
                let versionId = reference?.versionId ?? BibleVersionRepository.shared.downloadedVersionIds.first ?? 3034
                self.reference = BibleReference(versionId: versionId, bookUSFM: "JHN", chapter: 1)
                self.showBookIntro = false
            }
        }

        self.onVerseTap = onVerseTap
        self.onNoteIndicatorTap = onNoteIndicatorTap
        self.onReferenceChange = onReferenceChange
        self.onChapterComplete = onChapterComplete
        self.verseSelectionStyle = verseSelectionStyle
        self.audioActiveIndicatorColor = audioActiveIndicatorColor
        self.authentication = authentication
        self.isSignedIn = authentication.isSignedIn
        self.highlightsViewModel = highlightsViewModel ?? BibleHighlightsViewModel()
        let shouldLoadVersionsViewModel = versionsViewModel == nil
        self.versionsViewModel = versionsViewModel ?? BibleVersionsViewModel()
        self.versionsViewModel.onSignInRequired = { [weak self] in
            self?.onSignInRequired()
        }

        loadUserSettingsFromStorage()  // will overwrite colorTheme, fontFamily, etc.
        self.versionsViewModel.colorTheme = colorTheme

        ReaderFonts.installFontsIfNeeded()

        if shouldLoadVersionsViewModel {
            let initialVersionId = self.reference.versionId
            Task { [weak self] in
                await self?.versionsViewModel.loadInitialState(initialVersionId: initialVersionId)
            }
        }

        observeCurrentVersion()
    }

    // Reacts to BibleVersionsViewModel.currentVersion changes by updating
    // the reader's reference. The Observation framework's tracking is one-shot,
    // so the method re-arms itself after each fired change.
    private func observeCurrentVersion() {
        withObservationTracking {
            _ = versionsViewModel.currentVersion
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeCurrentVersion()
                if let version = self?.versionsViewModel.currentVersion {
                    self?.handleVersionPicked(version)
                }
            }
        }
    }

    var verseActionsDrawerAnimation: Animation {
        isReduceMotionEnabled ? .easeInOut(duration: 0.2) : .smooth(duration: 0.3)
    }

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
            verseNumberColor: readerVerseNumColor,
            wordsOfChristColor: readerWordsOfChristColor,
            footnoteMode: .image,
            footnoteMarker: nil,
            verseSelectionStyle: verseSelectionStyle,
            noteIndicatorBoxColor: readerButtonPrimaryColor,
            noteIndicatorBoxHighlightColor: readerButtonContrastColor.opacity(0.1),
            audioActiveIndicatorColor: audioActiveIndicatorColor
        )
    }

    /// Aligns the reader's reference to a newly picked version and triggers a
    /// header selection change to load its content. No-ops when the reference's
    /// versionId already matches — this is the guard that prevents
    /// `onHeaderSelectionChange` from looping back through the
    /// `currentVersion` observation chain.
    func handleVersionPicked(_ version: BibleVersion) {
        Task {
            await handleVersionPicked(version)
        }
    }

    func handleVersionPicked(_ version: BibleVersion) async {
        guard reference.versionId != version.id else {
            return
        }
        reference = BibleReference(versionId: version.id, bookUSFM: reference.bookUSFM, chapter: reference.chapter)
        await onHeaderSelectionChange(reference, showIntro: false)
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
        fontFamily = if let savedFamily = savedValue.fontFamily, ReaderFonts.isPermittedFont(savedFamily) {
            savedFamily
        } else {
            ReaderFonts.defaultFontFamily
        }
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

    func openFontSettings() {
        showingFontList = false
        showingFontSettings = true
    }

    func decreaseFontSize() {
        if let newSize = ReaderFonts.nextSmallerSize(currentSize: textOptions.fontSize) {
            setFont(size: newSize)
        }
    }

    func increaseFontSize() {
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

    func cycleLineSpacing() {
        lineSpacing = ReaderFonts.nextLineSpacing(currentSpacing: lineSpacing)
        saveUserSettingsToStorage()
    }

    func setColorTheme(_ theme: ReaderTheme) {
        colorTheme = theme
        versionsViewModel.colorTheme = theme
        saveUserSettingsToStorage()
    }

    func updateSignInState() async {
        isSignedIn = await authentication.hasValidToken()
    }

    func signIn() {
        if isSignedIn {
            return
        }
        startSignInFlow = true
    }

    func signOut() {
        showSignOutConfirmation = true
    }

    func confirmSignOut() {
        authentication.signOut()
        highlightsViewModel.reset()
        isSignedIn = false
    }

    // MARK: - Versions list

    /// Maps from a languageCode to a list of BibleVersion objects for that language.
    var versionsInLanguage: [String: [BibleVersion]] = [:]

    /// Holds minimal information about all Bible versions available to this app, in all languages.
    var permittedVersionsList: [YouVersionAPI.Bible.BibleVersionMinimalInfo]? // swiftlint:disable:this collection_suffix_property

    /// Returns minimal information about all Bible versions available to this app, in all languages.
    /// On error or when offline, returns nil
    func permittedVersionsListing() async -> [YouVersionAPI.Bible.BibleVersionMinimalInfo]? {
        if let permittedVersionsList { // swiftlint:disable:this collection_suffix_property
            return permittedVersionsList
        }

        let versions = try? await YouVersionAPI.Bible.permittedVersions(forLanguageTag: nil)

        if let versions {
            await MainActor.run {
                if self.permittedVersionsList == nil {
                    self.permittedVersionsList = versions
                }
            }
        }
        return versions
    }

    private var versionsBeingFetched: Set<String> = []

    /// Causes data to be fetched, if necessary, to fill out `versionsInLanguage` for the given language code.
    /// The fetch happens in a separate task. UI should observe `versionsInLanguage` and update when it does.
    func fetchVersionsInLanguage(code: String) {
        guard versionsInLanguage[code] == nil else {
            return  // no need to fetch: we already have the data
        }
        guard !versionsBeingFetched.contains(code) else {
            return
        }
        versionsBeingFetched.insert(code)
        Task {
            if let unsortedVersions = try? await YouVersionAPI.Bible.versions(forLanguageTag: code) {
                let sortedVersions = unsortedVersions.sorted {
                    let a = $0.localizedTitle ?? $0.title ?? $0.localizedAbbreviation ?? $0.abbreviation ?? String($0.id)
                    let b = $1.localizedTitle ?? $1.title ?? $1.localizedAbbreviation ?? $1.abbreviation ?? String($1.id)
                    return a < b
                }
                await MainActor.run {
                    self.versionsInLanguage[code] = sortedVersions
                }
            }
            _ = await MainActor.run {
                versionsBeingFetched.remove(code)
            }
        }
    }

    var showGenericAlert = false
    var textForGenericAlertTitle = ""
    var textForGenericAlertBody = ""
    private(set) var textForGenericAlertOKButton = "OK"
    var showFullProgressViewOverlay = false

    // MARK: - Languages picking

    var suggestedLanguagesList: [LanguageOverview] = [] // swiftlint:disable:this collection_suffix_property
    var chosenLanguage: String?
    var languageNames: [String: String] = [:]

    private func loadSuggestedLanguages() async {
        let region = Locale.current.region?.identifier ?? "US"
        do {
            suggestedLanguagesList = try await YouVersionAPI.Languages.languages(country: region, fields: ["language", "display_names"])
        } catch {
            print("Error fetching languages: \(error.localizedDescription)")
        }
    }

    /// Returns languages likely to be ones the user will want. Doesn't return any for which we have no Bible versions.
    var suggestedLanguages: [String] {
        guard !self.suggestedLanguagesList.isEmpty else {
            return ["en", "es"]
        }
        let codes = extractLanguageCodes(languages: self.suggestedLanguagesList)
        guard let versionsInfo = permittedVersionsList else {
            return codes
        }
        let ret = codes.filter { code in
            versionsInfo.isEmpty || versionsInfo.contains(where: { $0.languageTag == code })
        }
        return ret
    }

    func languageName(_ lang: String) -> String {
        languageNames[lang] ?? Locale.current.localizedString(forLanguageCode: lang) ?? lang
    }

    /// Returns language codes from the list, preferring the 3-letter language codes
    private func extractLanguageCodes(languages: [LanguageOverview]) -> [String] {
        let languageCodes = languages.compactMap { $0.language }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        return languageCodes.filter { languageCode in
            if seen.contains(languageCode) {
                return false
            } else {
                seen.insert(languageCode)
                return true
            }
        }
    }

    // MARK: - VersionsPicker settings, for Version selection and manipulation

    enum VersionsPickerScreen: Hashable {
        case myVersions
        case moreVersions
        case versionInfo
        case versionDownload
        case languages
    }

    var showingVersionsStack = false
    var versionsPickerStack: [VersionsPickerScreen] = []

    var selectedVersion: BibleVersion?

    var organizationInfo: [String: Organization] = [:]

    func organizationName(id: String) -> String? {
        guard let org = organizationInfo[id] else {
            Task {
                if let data = try? await YouVersionAPI.Organizations.organization(id: id) {
                    organizationInfo[id] = data
                }
            }
            return nil
        }
        return org.name
    }

    private struct ReaderSettings: Codable {
        let fontFamily: String?
        let fontSize: CGFloat?
        let lineSpacing: CGFloat?
        let colorTheme: Int?
    }
}
