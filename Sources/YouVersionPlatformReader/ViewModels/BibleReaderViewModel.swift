import CoreText
import Foundation
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

@MainActor
@Observable
final class BibleReaderViewModel: ReaderColors {
    private let userDefaultsKeyForBibleReference = "bible-reader-view--reference"
    private let userDefaultsKeyForMyVersions = "bible-reader-view--my-versions"
    var reference: BibleReference {
        didSet {
            if let data = try? JSONEncoder().encode(reference) {
                UserDefaults.standard.set(data, forKey: userDefaultsKeyForBibleReference)
            }
        }
    }
    let highlightsViewModel: BibleHighlightsViewModel
    var version: BibleVersion?
    let versionRepository = BibleVersionRepository()

    init(reference: BibleReference? = nil, highlightsViewModel: BibleHighlightsViewModel? = nil) {
        // grab the saved data first, because initializing myVersions will clear the saved data.
        let savedIds = UserDefaults.standard.array(forKey: userDefaultsKeyForMyVersions) as? [Int] ?? []

        if let reference {
            self.reference = reference
        } else {
            if let data = UserDefaults.standard.data(forKey: userDefaultsKeyForBibleReference),
            let savedValue = try? JSONDecoder().decode(BibleReference.self, from: data) {
                self.reference = savedValue
            } else {
                // no specified or saved version, so, pick a downloaded one, else a safe default.
                let downloads = VersionDownloadCache.downloadedVersions
                let versionId = reference?.versionId ?? downloads.first ?? savedIds.first ?? 206
                self.reference = BibleReference(versionId: versionId, bookUSFM: "JHN", chapter: 1)
            }
        }

        self.highlightsViewModel = highlightsViewModel ?? BibleHighlightsViewModel()
        self.colorTheme = ReaderTheme.allThemes.first

        self.myVersions = []
        self.languagesList = []

        ReaderFonts.installFontsIfNeeded()

        Task {
            await loadVersionIfNeeded(savedIds: savedIds)
            await restoreMyVersions(savedIds: savedIds)
            await loadSuggestedLanguages()
            await removeUnpermittedVersions()
        }
    }

    private func removeUnpermittedVersions() async {
        if let permittedVersions = try? await YouVersionAPI.Bible.versions() {
            let permittedIds = Set(permittedVersions.map(\.id))
            await versionRepository.removeUnpermittedVersions(permittedIds: permittedIds)

            for version in self.myVersions where !permittedIds.contains(version.id) {
                self.myVersions.remove(version)
            }
            if !permittedIds.contains(reference.versionId) {
                await selectFallbackVersion(savedIds: Array(self.myVersions.map(\.id)))
            }
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
    var showingVerseActionsDrawer = false
    var selectedVerses: Set<BibleReference> = []

    var showingBookPicker = false
    private var showingChapterPicker = false
    var headerExpandedBookCode: String?

    let readerMaxWidth = CGFloat(700)  // of the reader and the verse action drawer, maybe others

    // MARK: - Font settings

    private var fontFamily: String? = ReaderFonts.defaultFontFamily
    private var fontSize: CGFloat? = ReaderFonts.defaultFontSize
    private var lineSpacing = ReaderFonts.defaultLineSpacing

    var textOptions: BibleTextOptions {
        ReaderFonts.installFontsIfNeeded()
        return BibleTextOptions(
            fontFamily: fontFamily ?? "Georgia",
            fontSize: fontSize ?? 18,
            // TODO: maybe have one of these spacings be a delta added to the other:
            lineSpacing: lineSpacing,
            paragraphSpacing: lineSpacing,
            textColor: readerTextPrimaryColor,
            wocColor: wordsOfChristColor
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
    }

    func selectNextLineSpacing() {
        lineSpacing = ReaderFonts.nextLineSpacing(currentSpacing: lineSpacing)
    }

    // MARK: Colors
    
    var readerCanvasPrimaryColor: Color {
        colorTheme?.background ?? (colorTheme?.colorScheme != .dark ? readerWhiteColor : readerBlackColor)
    }

    var readerTextPrimaryColor: Color {
        colorTheme?.foreground ?? (colorTheme?.colorScheme != .dark ? readerBlackColor : readerWhiteColor)
    }

    var readerTextMutedColor: Color {
        readerTextPrimaryColor == readerWhiteColor ? Color(hex: "#636161") : Color(hex: "#bfbdbd")
    }

    var colorTheme: ReaderTheme?

    // MARK: - Sign In & Out

    var startSignInFlow = false
    private(set) var isSignedIn = false
    var showSignOutConfirmation = false

    func updateSignInState() {
        isSignedIn = YouVersionAPI.isSignedIn
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

    var permittedVersions: [BibleVersion] = []

    var showFullProgressViewOverlay = false

    // MARK: - My Versions
    // TODO: persist myVersions, and have it not be MRU but user-controlled.
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

    var languagesList: [LanguageOverview]
    var chosenLanguage: String?

    func loadSuggestedLanguages() async {
        let region = Locale.current.region?.identifier ?? "US"
        do {
            languagesList = try await YouVersionAPI.Languages.languages(country: region)
        } catch {
            print("Error fetching languages: \(error.localizedDescription)")
        }
    }

    var suggestedLanguages: [String] {
        guard !self.languagesList.isEmpty else {
            return ["eng", "spa"]
        }
        let codes = extractLanguageCodes(languages: self.languagesList)
        let ret = codes.filter { code in
            permittedVersions.isEmpty || permittedVersions.contains(where: { $0.languageTag == code })
        }
        return ret
    }

    /// Returns language codes from the list, preferring the 3-letter language codes
    private func extractLanguageCodes(languages: [LanguageOverview]) -> [String] {
        let languageCodes = languages.map { $0.language }

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
}
