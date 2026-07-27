#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
import CoreText
import Foundation
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// A verse the reader should scroll to, and whether it should be focused (dimming
/// the rest of the chapter) once it lands.
struct ScrollTarget: Equatable {
    let reference: BibleReference
    let shouldFocus: Bool
}

/// The single scroll intent a navigation produces. The reader observes this and
/// performs exactly one of: nothing, scroll to the top, or scroll to a reference.
enum ScrollAction: Equatable {
    case none
    case top
    case reference(ScrollTarget)
}

@MainActor
@Observable
final class BibleReaderViewModel: ReaderThemeProviding {
    private static let highlightsPermission = "highlights"

    private let userDefaultsKeyForBibleReference = "bible-reader-view--reference"
    private let userDefaultsKeyForBibleDisplayIntro = "bible-reader-view--displayintro"
    private let userDefaultsKeyForShowsFullChapter = "bible-reader-view--showsfullchapter"
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
    var isChangingChapter = false
    var scrollAction: ScrollAction = .none
    var showsFullChapter: Bool {
        didSet {
            UserDefaults.standard.set(showsFullChapter, forKey: userDefaultsKeyForShowsFullChapter)
        }
    }
    /// The target the reader should scroll to, if the current ``scrollAction`` is a reference.
    var scrollTarget: ScrollTarget? {
        if case .reference(let target) = scrollAction {
            target
        } else {
            nil
        }
    }
    private(set) var focusedReference: BibleReference?
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

    var colorScheme: ColorScheme = .light {
        didSet { syncVersionsViewModelTheme() }
    }

    private var userSelectedTheme: ReaderTheme? {
        didSet { syncVersionsViewModelTheme() }
    }

    /// The theme currently in effect. Returns the user's selected theme when
    /// they have one, otherwise a built-in theme matching the device's
    /// appearance (``colorScheme``).
    var colorTheme: ReaderTheme? {
        userSelectedTheme ?? colorScheme.readerTheme
    }

    private func syncVersionsViewModelTheme() {
        versionsViewModel.colorTheme = colorTheme
    }

    // MARK: - Sign In & Out

    var startSignInFlow = false
    var showingDataExchangeConfirmation = false
    var startDataExchangeFlow = false
    var showSignOutConfirmation = false
    var showSignOutWithPendingHighlightsConfirmation = false
    private var pendingHighlight: PendingHighlight?

    var isSignedIn: Bool {
        authentication.isSignedIn
    }

    /// Creates a view model displaying `reference`.
    convenience init(
        reference: BibleReference,
        showsFullChapter: Bool = false,
        highlightsViewModel: BibleHighlightsViewModel? = nil,
        verseSelectionStyle: VerseSelectionStyle = .solid,
        versionsViewModel: BibleVersionsViewModel? = nil,
        onVerseTap: ((BibleReference) -> Void)? = nil,
        authentication: BibleReaderAuthentication? = nil
    ) {
        self.init(
            initialReference: reference,
            showsFullChapter: showsFullChapter,
            highlightsViewModel: highlightsViewModel,
            verseSelectionStyle: verseSelectionStyle,
            versionsViewModel: versionsViewModel,
            onVerseTap: onVerseTap,
            authentication: authentication
        )
    }

    /// Creates a view model that restores the last-viewed passage — the reference,
    /// intro visibility, and full-chapter display mode — or falls back to John 1
    /// when nothing has been saved. No verse scroll is armed on restore, so a user
    /// who had scrolled within the chapter isn't pulled back to the saved verse.
    convenience init(
        highlightsViewModel: BibleHighlightsViewModel? = nil,
        verseSelectionStyle: VerseSelectionStyle = .solid,
        versionsViewModel: BibleVersionsViewModel? = nil,
        onVerseTap: ((BibleReference) -> Void)? = nil,
        authentication: BibleReaderAuthentication? = nil
    ) {
        self.init(
            initialReference: nil,
            showsFullChapter: false,
            highlightsViewModel: highlightsViewModel,
            verseSelectionStyle: verseSelectionStyle,
            versionsViewModel: versionsViewModel,
            onVerseTap: onVerseTap,
            authentication: authentication
        )
    }

    private init(
        initialReference: BibleReference?,
        showsFullChapter: Bool,
        highlightsViewModel: BibleHighlightsViewModel?,
        verseSelectionStyle: VerseSelectionStyle,
        versionsViewModel: BibleVersionsViewModel?,
        onVerseTap: ((BibleReference) -> Void)?,
        authentication: BibleReaderAuthentication?
    ) {
        let authentication = authentication ?? .default
        if let initialReference {
            self.reference = initialReference
            self.showBookIntro = false
            self.showsFullChapter = showsFullChapter
        } else {
            if let data = UserDefaults.standard.data(forKey: userDefaultsKeyForBibleReference),
               let savedValue = try? JSONDecoder().decode(BibleReference.self, from: data) {
                self.reference = savedValue
                self.showBookIntro = UserDefaults.standard.bool(forKey: userDefaultsKeyForBibleDisplayIntro)
                self.showsFullChapter = UserDefaults.standard.bool(forKey: userDefaultsKeyForShowsFullChapter)
            } else {
                // no saved reference, so, pick a downloaded version, else a safe default.
                let versionId = BibleVersionRepository.shared.downloadedVersionIds.first ?? 3034
                self.reference = BibleReference(versionId: versionId, bookUSFM: "JHN", chapter: 1)
                self.showBookIntro = false
                self.showsFullChapter = showsFullChapter
            }
        }
        self.onVerseTap = onVerseTap
        self.verseSelectionStyle = verseSelectionStyle
        self.authentication = authentication
        self.highlightsViewModel = highlightsViewModel ?? BibleHighlightsViewModel()
        let shouldLoadVersionsViewModel = versionsViewModel == nil
        self.versionsViewModel = versionsViewModel ?? BibleVersionsViewModel()
        self.versionsViewModel.onSignInRequired = { [weak self] in
            self?.onSignInRequired()
        }

        loadUserSettingsFromStorage()  // will overwrite colorTheme, fontFamily, etc.
        syncVersionsViewModelTheme()

        ReaderFonts.installFontsIfNeeded()

        if shouldLoadVersionsViewModel {
            let initialVersionId = self.reference.versionId
            Task { [weak self] in
                await self?.versionsViewModel.loadInitialState(initialVersionId: initialVersionId)
            }
        }

        observeCurrentVersion()

        if initialReference != nil {
            setScrollTarget()
        }
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
            lineSpacing: lineSpacing,
            paragraphSpacing: nil,
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

    /// Sets the current ``reference``'s verse as the target the reader should scroll to
    /// once its chapter lays out.
    func setScrollTarget(shouldFocus: Bool = false) {
        guard showsFullChapter && reference.verseStart != nil else {
            return
        }
        scrollAction = .reference(ScrollTarget(reference: reference, shouldFocus: shouldFocus))
    }

    /// Marks the current ``scrollAction`` as consumed once the reader has begun acting on it,
    /// without ending the chapter change (chrome stays suppressed until the scroll settles).
    func clearScrollAction() {
        scrollAction = .none
    }

    /// Puts the reader into the same state a freshly opened chapter would be in.
    func resetScrollStateForNewChapter() {
        lastScrollOffset = 0
        showChrome = true
        scrollAction = .top
        clearFocus()
    }

    /// Ends an in-flight chapter change by optionally clearing any armed scroll
    /// and resetting the isChangingChapter flag.
    func finishChapterChange(clearingScroll: Bool = true) {
        if clearingScroll {
            scrollAction = .none
        }
        isChangingChapter = false
    }

    /// Focuses `reference`'s verse (or verse range), dimming the rest of the chapter.
    func focusReference(_ reference: BibleReference) {
        guard reference.verseStart != nil
              && reference.chapterReference == self.reference.chapterReference else {
            return
        }
        focusedReference = reference
    }

    func clearFocus() {
        focusedReference = nil
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
        fontSize = ReaderFonts.nextLargerSize(currentSize: (savedValue.fontSize ?? ReaderFonts.defaultFontSize) - 0.001)
        lineSpacing = ReaderFonts.nextLineSpacing(currentSpacing: (savedValue.lineSpacing ?? ReaderFonts.defaultLineSpacing) - 0.001)
        if let savedThemeId = savedValue.colorTheme {
            userSelectedTheme = ReaderTheme.theme(withId: savedThemeId)
        }
        // else: no saved theme yet — userSelectedTheme stays nil and colorTheme
        // tracks the device's system color scheme until the user picks one.
    }

    func saveUserSettingsToStorage() {
        let settings = ReaderSettings(
            fontFamily: fontFamily,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            colorTheme: userSelectedTheme?.id
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
        userSelectedTheme = theme
        saveUserSettingsToStorage()
    }

    func updateSignInState() async {
        _ = await authentication.hasValidToken()
    }

    /// Continues a pending highlight action after the user has completed sign-in.
    func continuePendingHighlightAfterSignIn() {
        guard pendingHighlight != nil && isSignedIn else {
            return
        }
        if authentication.hasPermission(Self.highlightsPermission) {
            applyPendingHighlight()
            reloadCurrentChapterHighlights()
        } else {
            startDataExchangeFlow = true
        }
    }

#if !os(tvOS)
    func startDataExchange(contextProvider: ASWebAuthenticationPresentationContextProviding) {
        startDataExchange(with: DataExchangeSession(contextProvider: contextProvider))
    }
#else
    func startDataExchange() {
        startDataExchange(with: DataExchangeSession())
    }
#endif

    private func startDataExchange(with session: DataExchangeSession) {
        Task {
            do {
                startDataExchangeFlow = false
                let permissions = try await session.requestDataExchange(
                    permissions: [Self.highlightsPermission]
                )
                completeDataExchangeFlow(with: permissions)
            } catch {
                completeDataExchangeFlow(with: [])
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
    func completeDataExchangeFlow(with grantedPermissions: [String]) {
        startDataExchangeFlow = false
        showingDataExchangeConfirmation = false
        if grantedPermissions.contains(Self.highlightsPermission) {
            applyPendingHighlight()
            reloadCurrentChapterHighlights()
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
                    permissions: ["profile", Self.highlightsPermission],
                    contextProvider: contextProvider
                )
                await updateSignInState()
                if result.permissionValues.contains(Self.highlightsPermission) {
                    continuePendingHighlightAfterSignIn()
                } else {
                    clearPendingHighlight()
                }
            } catch {
                YouVersionPlatformLogger.error("\(error)", category: "Reader")
            }
        }
    }
#else
    func startSignIn() {
        Task {
            do {
                startSignInFlow = false
                let result = try await YouVersionAPI.Users.signIn(
                    permissions: ["profile", Self.highlightsPermission]
                )
                await updateSignInState()
                if result.permissionValues.contains(Self.highlightsPermission) {
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
        if highlightsViewModel.hasPendingOperations {
            showSignOutWithPendingHighlightsConfirmation = true
        } else {
            showSignOutConfirmation = true
        }
    }

    func confirmSignOut() {
        authentication.signOut()
        highlightsViewModel.reset()
        clearPendingHighlight()
    }

    func confirmPendingHighlightsSignOut() {
        highlightsViewModel.reset()
        confirmSignOut()
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
            guard authentication.isSignInEnabled else {
                return
            }
            pendingHighlight = PendingHighlight(references: references, color: color)
            showingSignInSheet = true
            return
        }
        
        if authentication.hasPermission(Self.highlightsPermission) {
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

    private func reloadCurrentChapterHighlights() {
        highlightsViewModel.ensureHighlightsForChapterLoaded(reference, forceReload: true)
    }

    private func clearPendingHighlight() {
        pendingHighlight = nil
        showingDataExchangeConfirmation = false
        startDataExchangeFlow = false
    }
}
