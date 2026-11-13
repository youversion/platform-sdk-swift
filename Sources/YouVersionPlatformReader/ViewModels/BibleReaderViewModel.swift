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

enum SearchStatus: Equatable {
    case idle
    case searching
    case completed
    case failed
}

struct SearchPageLoadTrigger: Equatable {
    let pageToken: String?
    let interruptionCount: Int
}

enum SearchCanonFilter: CaseIterable {
    case oldTestament
    case newTestament
    case both

    var canons: Set<String>? {
        switch self {
        case .oldTestament: ["ot", "old_testament"]
        case .newTestament: ["nt", "new_testament"]
        case .both: nil
        }
    }
}

@MainActor
@Observable
final class BibleReaderViewModel: ReaderThemeProviding {
    private static let highlightsPermission = "highlights"
    static let notesPermission = YouVersionAPI.Users.writeNotesPermission
    static let dataExchangePermissions: Set<String> = [highlightsPermission]

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
    var noteDraft: BibleReaderNoteDraft?
    var pendingNoteDraft: BibleReaderNoteDraft?
    var isNoteAuthorizationPending = false
    var showingSearchSheet = false
    var isReduceMotionEnabled = false
    var selectedVerses: Set<BibleReference> = []
    var showingBookPicker = false
    private var showingChapterPicker = false
    var headerExpandedBookCode: String?
    var footnotesToDisplay: [BibleFootnote] = []

    // MARK: - Search

    var searchQuery = ""
    var suggestedSearchQueries: [YouVersionSearchQuery] = []
    var trendingSearchQueries: [YouVersionSearchQuery] = []
    var recentSearchQueries: [String] = []
    var searchResults: [BibleReference] = []
    var searchVersion: BibleVersion?
    var isLoadingSearchQueries = false
    var searchStatus: SearchStatus = .idle
    var searchResultTextByPassageID: [String: String] = [:]
    var completedSearchQuery: String?
    var completedSearchVersionID: Int?
    var submittedSearchQuery: String?
    var searchQueryRequestID: UUID?
    var searchRequestID: UUID?
    var nextSearchPageToken: String?
    var nextSearchPageRequestID: UUID?
    var hasNextSearchPageLoadError = false
    var interruptedSearchPageLoadCount = 0
    var searchCanonFilter: SearchCanonFilter = .both

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
    private var isSigningIn = false
    var showingDataExchangeConfirmation = false
    var startDataExchangeFlow = false
    var showSignOutConfirmation = false
    var showSignOutWithPendingHighlightsConfirmation = false
    private var pendingHighlight: PendingHighlight?
    private var isHighlightAuthorizationPending = false

    var isSignedIn: Bool {
        authentication.isSignedIn
    }

    var signedInAccount: BibleReaderAccount? {
        authentication.account
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
                self.reference = BibleReference(versionId: versionId, bookId: "JHN", chapter: 1)
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

    var canDecreaseFontSize: Bool {
        ReaderFonts.nextSmallerSize(currentSize: textOptions.fontSize) != nil
    }

    var canIncreaseFontSize: Bool {
        ReaderFonts.nextLargerSize(currentSize: textOptions.fontSize) != nil
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
        reference = BibleReference(versionId: version.id, bookId: reference.bookId, chapter: reference.chapter)
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

    @discardableResult
    func updateSignInState() async -> Bool {
        notesAuthenticationDidChange()
        let hasValidToken = await authentication.hasValidToken()
        notesAuthenticationDidChange()
        return hasValidToken
    }

    /// Continues a pending highlight action after the user has completed sign-in.
    func continuePendingHighlightAfterSignIn() {
        guard pendingHighlight != nil && isHighlightAuthorizationPending && isSignedIn else {
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
                    permissions: Self.dataExchangePermissions
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
        guard isSignedIn && isHighlightAuthorizationPending && pendingHighlight != nil else {
            return
        }
        showingDataExchangeConfirmation = false
        startDataExchangeFlow = true
    }

    /// Pauses permission consent, retaining the original verses and color for an explicit retry.
    func cancelDataExchangePrompt() {
        let shouldRestoreSelection = isHighlightAuthorizationPending
        isHighlightAuthorizationPending = false
        showingDataExchangeConfirmation = false
        startDataExchangeFlow = false
        if shouldRestoreSelection, let pendingHighlight {
            selectedVerses = pendingHighlight.references
            showingVerseActionsDrawer = !selectedVerses.isEmpty
        }
    }

    /// Completes the just-in-time data exchange browser flow.
    func completeDataExchangeFlow(with grantedPermissions: [String]) {
        startDataExchangeFlow = false
        showingDataExchangeConfirmation = false
        if isHighlightAuthorizationPending && isSignedIn && grantedPermissions.contains(Self.highlightsPermission) {
            applyPendingHighlight()
            reloadCurrentChapterHighlights()
        } else {
            cancelDataExchangePrompt()
        }
    }

    var hasNotesPermission: Bool {
        authentication.hasPermission(Self.notesPermission)
    }

    static var signInPermissions: [String] {
        Set(YouVersionPlatformConfiguration.authData?.permissionValues ?? [])
            .subtracting([YouVersionAPI.Users.readNotesPermission, YouVersionAPI.Users.writeNotesPermission])
            .union(dataExchangePermissions)
            .union([YouVersionAPI.Users.readNotesPermission, YouVersionAPI.Users.writeNotesPermission])
            .union(["profile"])
            .sorted()
    }

    /// Resumes only reader actions whose permission was granted during sign-in.
    func completeSignInFlow(with grantedPermissions: [String]) {
        notesAuthenticationDidChange()
        startSignInFlow = false
        if isSignedIn && grantedPermissions.contains(Self.highlightsPermission) {
            continuePendingHighlightAfterSignIn()
        } else {
            cancelDataExchangePrompt()
        }
        continuePendingNote(with: grantedPermissions)
    }

    /// Pauses deferred actions when the sign-in prompt is dismissed without starting login.
    func cancelSignInPrompt() {
        guard !isSigningIn else {
            return
        }
        cancelSignInFlow()
    }

    /// Pauses cancelled or failed authentication without discarding either pending action.
    func cancelSignInFlow() {
        startSignInFlow = false
        isSigningIn = false
        cancelDataExchangePrompt()
        cancelPendingNote()
    }

#if !os(tvOS)
    func startSignIn(contextProvider: ASWebAuthenticationPresentationContextProviding) {
        Task {
            defer { isSigningIn = false }
            do {
                startSignInFlow = false
                let result = try await YouVersionAPI.Users.signIn(
                    permissions: Self.signInPermissions,
                    contextProvider: contextProvider
                )
                await updateSignInState()
                completeSignInFlow(with: result.permissionValues)
            } catch {
                cancelSignInFlow()
                YouVersionPlatformLogger.error("\(error)", category: "Reader")
            }
        }
    }
#else
    func startSignIn() {
        Task {
            defer { isSigningIn = false }
            do {
                startSignInFlow = false
                let result = try await YouVersionAPI.Users.signIn(
                    permissions: Self.signInPermissions
                )
                await updateSignInState()
                completeSignInFlow(with: result.permissionValues)
            } catch {
                cancelSignInFlow()
                YouVersionPlatformLogger.error("\(error)", category: "Reader")
            }
        }
    }
#endif

    func signIn() {
        if isSignedIn {
            return
        }
        isSigningIn = true
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
        invalidateNoteDrafts()
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
            guard YouVersionPlatformConfiguration.isSignInEnabled else {
                return
            }
            pendingHighlight = PendingHighlight(references: references, color: color)
            isHighlightAuthorizationPending = true
            showingSignInSheet = true
            return
        }
        
        pendingHighlight = PendingHighlight(references: references, color: color)
        isHighlightAuthorizationPending = true
        if authentication.hasPermission(Self.highlightsPermission) {
            applyPendingHighlight()
        } else {
            showingDataExchangeConfirmation = true
        }
    }

    private func applyPendingHighlight() {
        guard isHighlightAuthorizationPending && isSignedIn, let pendingHighlight else {
            return
        }
        self.pendingHighlight = nil
        isHighlightAuthorizationPending = false
        applyHighlight(references: pendingHighlight.references, color: pendingHighlight.color)
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
        isHighlightAuthorizationPending = false
        showingDataExchangeConfirmation = false
        startDataExchangeFlow = false
    }
}
