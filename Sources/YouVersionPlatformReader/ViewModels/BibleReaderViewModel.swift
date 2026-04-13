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
    private let userDefaultsKeyForMyVersions = "bible-reader-view--my-versions"
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
    var version: BibleVersion?
    let versionRepository = BibleVersionRepository()
    let onVerseTap: ((BibleReference) -> Void)?

    init(reference: BibleReference? = nil, highlightsViewModel: BibleHighlightsViewModel? = nil, onVerseTap: ((BibleReference) -> Void)? = nil) {
        // grab the saved data first, because initializing myVersions will clear the saved data.
        let savedIds = UserDefaults.standard.array(forKey: userDefaultsKeyForMyVersions) as? [Int] ?? []

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
                let versionId = reference?.versionId ?? downloads.first ?? savedIds.first ?? 3034
                self.reference = BibleReference(versionId: versionId, bookUSFM: "JHN", chapter: 1)
                self.showBookIntro = false
            }
        }

        self.onVerseTap = onVerseTap
        self.highlightsViewModel = highlightsViewModel ?? BibleHighlightsViewModel()
        self.colorTheme = ReaderTheme.theme()
        self.myVersions = []
        self.suggestedLanguagesList = []

        loadUserSettingsFromStorage()  // will overwrite colorTheme, fontFamily, etc.

        ReaderFonts.installFontsIfNeeded()
        Task {
            await loadVersionIfNeeded(savedIds: savedIds)
            await restoreMyVersions(savedIds: savedIds)
            await loadSuggestedLanguages()
            await removeUnpermittedVersions()
        }
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

    private func removeUnpermittedVersions() async {
        guard let permittedVersions = await permittedVersionsListing() else {
            return  // when offline, we don't get a list, but don't delete anything!
        }
        let permittedIds = Set(permittedVersions.map(\.id))
        await versionRepository.removeUnpermittedVersions(permittedIds: permittedIds)

        for version in self.myVersions where !permittedIds.contains(version.id) {
            self.myVersions.remove(version)
        }
        if !permittedIds.contains(reference.versionId) {
            await selectFallbackVersion(savedIds: Array(self.myVersions.map(\.id)))
        }
    }

    private func restoreMyVersions(savedIds: [Int]) async {
        for id in savedIds {
            if let version = try? await versionRepository.versionIfCached(id) {
                self.myVersions.insert(version)
            }
        }

        // downloaded versions must also be in MyVersions, otherwise they couldn't be deleted.
        let downloads = VersionDownloadCache.downloadedVersions
        for id in downloads {
            if self.myVersions.contains(where: { $0.id == id }) {
                continue
            }
            if let version = try? await versionRepository.versionIfCached(id) {
                self.myVersions.insert(version)
            }
        }
    }

    private func loadVersionIfNeeded(savedIds: [Int]) async {
        if self.version == nil || self.version!.id != reference.versionId {
            do {
                version = try await versionRepository.version(withId: reference.versionId)
                if let version {
                    self.myVersions.insert(version)
                }
            } catch YouVersionAPIError.notPermitted {
                await selectFallbackVersion(savedIds: savedIds)
            } catch {
                print("Error loading default version: \(error)")
            }
        }
    }

    private func selectFallbackVersion(savedIds: [Int]) async {
        guard let nextBestVersion = await findAnyAcceptableVersion(savedIds: Set(savedIds)),
        let version = try? await versionRepository.version(withId: nextBestVersion)
        else {
            // bring up the UI, let the user choose.
            versionsStackPush(to: .moreVersions)
          return
        }
        self.version = version
        self.reference = BibleReference(versionId: version.id, bookUSFM: reference.bookUSFM, chapter: reference.chapter)
        self.myVersions.insert(version)
    }

    private func findAnyAcceptableVersion(savedIds: Set<Int>) async -> Int? {
        let downloads = VersionDownloadCache.downloadedVersions
        if !downloads.isEmpty {
            return downloads.first!
        }

        if let versions = try? await YouVersionAPI.Bible.versions() {
            // are any of the permitted versions in their myVersions list?
            for version in versions where savedIds.contains(version.id) {
                return version.id
            }

            // For now, fall back to a Bible in English.
            // It would be better to search for a bible in the device's language,
            // before defaulting to English.
            if let version = versions.first(where: { $0.languageTag == "en" }) {
                return version.id
            }

            if let version = versions.first {
                return version.id
            }
        } else {
            print("Could not fetch the permitted versions")
        }
        return nil  // at this point we must be offline or the app has been shut down. Give up.
    }

    var showGenericAlert = false
    var textForGenericAlertTitle = ""
    var textForGenericAlertBody = ""
    private(set) var textForGenericAlertOKButton = "OK"

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
            footnoteMarker: nil
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

    var colorTheme: ReaderTheme?

    func setColorTheme(_ theme: ReaderTheme) {
        colorTheme = theme
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

    // MARK: - Versions list

    /// Maps from a languageCode to a list of BibleVersion objects for that language.
    var versionsInLanguage: [String: [BibleVersion]] = [:]

    /// Holds minimal information about all Bible versions available to this app, in all languages.
    var permittedVersionsList: [YouVersionAPI.Bible.BibleVersionMinimalInfo]?

    /// Returns minimal information about all Bible versions available to this app, in all languages.
    /// On error or when offline, returns nil
    func permittedVersionsListing() async -> [YouVersionAPI.Bible.BibleVersionMinimalInfo]? {
        if let permittedVersionsList {
            return permittedVersionsList
        }

        let time1 = Date()
        let versions = try? await YouVersionAPI.Bible.permittedVersions(forLanguageTag: nil)
        let elapsed = Date().timeIntervalSince(time1)
        print("fetchBibleVersionMinimalInfo got \(versions?.count ?? -999) in \(String(format: "%.2f", elapsed)) seconds.")

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
            let time1 = Date()
            if let unsortedVersions = try? await YouVersionAPI.Bible.versions(forLanguageTag: code) {
                let elapsed = Date().timeIntervalSince(time1)
                print("fetchVersionsInLanguage('\(code)') got \(unsortedVersions.count) in \(String(format: "%.2f", elapsed)) seconds.")
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

    var showFullProgressViewOverlay = false

    // MARK: - My Versions
    var myVersions: Set<BibleVersion> = [] {
        didSet {
            Task {
                // The below iteration must be run in a Task to avoid view re-creation loops.
                let ids = myVersions.map { $0.id }
                UserDefaults.standard.set(ids, forKey: userDefaultsKeyForMyVersions)
            }
        }
    }

    var showVersionInfoSharingAlert = false
    var showVersionInfoSharingText = ""

    // MARK: - Languages picking

    var suggestedLanguagesList: [LanguageOverview]
    var chosenLanguage: String?
    var languageNames: [String: String] = [:]

    private func loadSuggestedLanguages() async {
        let region = Locale.current.region?.identifier ?? "US"
        do {
            let time1 = Date()
            suggestedLanguagesList = try await YouVersionAPI.Languages.languages(country: region, fields: ["language", "display_names"])
            let elapsed = Date().timeIntervalSince(time1)
            print("loadSuggestedLanguages got \(suggestedLanguagesList.count) in \(String(format: "%.2f", elapsed)) seconds.")
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
}
