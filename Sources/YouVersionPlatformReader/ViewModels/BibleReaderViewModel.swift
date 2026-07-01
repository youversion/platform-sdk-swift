#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
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
    let onVerseTap: ((BibleReference) -> Void)?
    let verseSelectionStyle: VerseSelectionStyle
    private let authentication: BibleReaderAuthentication

    // MARK: - UI state of the Reader itself
    var showChrome = true
    var lastScrollOffset: CGFloat = 0
    var scrollToTop = false
    var isChangingChapter = false
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
    var showingDataExchangeConfirmation = false
    var startDataExchangeFlow = false
    private(set) var isSignedIn: Bool
    var showSignOutConfirmation = false
    private var pendingHighlight: PendingHighlight?

    init(
        reference: BibleReference? = nil,
        highlightsViewModel: BibleHighlightsViewModel? = nil,
        verseSelectionStyle: VerseSelectionStyle = .solid,
        versionsViewModel: BibleVersionsViewModel? = nil,
        onVerseTap: ((BibleReference) -> Void)? = nil,
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
        self.verseSelectionStyle = verseSelectionStyle
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
            verseSelectionStyle: verseSelectionStyle
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

    /// Continues a pending highlight action after the user has completed sign-in.
    func continuePendingHighlightAfterSignIn() {
        guard pendingHighlight != nil && isSignedIn else {
            return
        }
        if authentication.hasPermission(.highlights) {
            applyPendingHighlight()
        } else {
            startDataExchangeFlow = true
        }
    }

    func startDataExchange(contextProvider: ASWebAuthenticationPresentationContextProviding) {
        Task {
            do {
                startDataExchangeFlow = false
#if !os(tvOS)
                let session = DataExchangeSession(contextProvider: contextProvider)
#else
                let session = DataExchangeSession()
#endif
                let result = try await session.requestDataExchange(permissions: [.highlights])
                completeDataExchangeFlow(with: result)
            } catch {
                completeDataExchangeFlow(with: DataExchangeRequestResult(status: .cancel, grantedPermissions: []))
                YouVersionPlatformLogger.error("startDataExchange failed: \(error)", category: "BibleReader")
            }
        }
    }

    /// Confirms the just-in-time data exchange prompt and starts the browser flow.
    func confirmDataExchangePrompt() {
        guard pendingHighlight != nil, isSignedIn else {
            return
        }
        showingDataExchangeConfirmation = false
        startDataExchangeFlow = true
    }

    /// Cancels the just-in-time data exchange prompt without changing highlights.
    func cancelDataExchangePrompt() {
        clearPendingHighlight()
    }

    /// Completes the just-in-time data exchange browser flow.
    func completeDataExchangeFlow(with result: DataExchangeRequestResult) {
        startDataExchangeFlow = false
        showingDataExchangeConfirmation = false
        if result.isGranted && result.grantedPermissions.contains(.highlights) {
            applyPendingHighlight()
        } else {
            clearPendingHighlight()
        }
    }

#if !os(tvOS)
    func startSignIn(contextProvider: ASWebAuthenticationPresentationContextProviding) {
        Task {
            do {
                startSignInFlow = false
                let result = try await YouVersionAPI.Users.signIn(
                    permissions: [.profile, .highlights],
                    contextProvider: contextProvider
                )
                await updateSignInState()
                if let permissions = result.permissions, permissions.contains(.highlights) {
                    continuePendingHighlightAfterSignIn()
                } else {
                    clearPendingHighlight()
                }
            } catch {
                YouVersionPlatformLogger.error("\(error)", category: "Reader")
            }
        }
    }
#endif

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
        clearPendingHighlight()
    }

    private struct ReaderSettings: Codable {
        let fontFamily: String?
        let fontSize: CGFloat?
        let lineSpacing: CGFloat?
        let colorTheme: Int?
    }

    private struct PendingHighlight {
        let references: Set<BibleReference>
        let color: String
    }

    /// Adds a highlight immediately or starts the just-in-time permission flow when needed.
    func addHighlightOrStartPermissionFlow(references: Set<BibleReference>, color: String) {
        guard !references.isEmpty else {
            return
        }
        if !isSignedIn {
            guard YouVersionPlatformConfiguration.isSignInEnabled else {
                return
            }
            pendingHighlight = PendingHighlight(references: references, color: color)
            showingSignInSheet = true
            return
        }
        
        if authentication.hasPermission(.highlights) {
            applyHighlight(references: references, color: color)
        } else {
            pendingHighlight = PendingHighlight(references: references, color: color)
            showingDataExchangeConfirmation = true
        }
    }

    private func applyPendingHighlight() {
        guard let pendingHighlight else {
            return
        }
        applyHighlight(references: pendingHighlight.references, color: pendingHighlight.color)
        self.pendingHighlight = nil
    }

    private func applyHighlight(references: Set<BibleReference>, color: String) {
        highlightsViewModel.addHighlights(references: Array(references), color: color)
        removeVerseSelection()
    }

    private func clearPendingHighlight() {
        pendingHighlight = nil
        showingDataExchangeConfirmation = false
        startDataExchangeFlow = false
    }
}
