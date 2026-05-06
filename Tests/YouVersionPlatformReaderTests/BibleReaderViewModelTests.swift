import SwiftUI
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader
@testable import YouVersionPlatformUI

private actor MockBibleVersionRepository: BibleVersionRepositoryProtocol {
    private var requestedVersionIds: [Int] = []
    private var thrownError: Error?

    func requestedIds() -> [Int] {
        requestedVersionIds
    }

    func setThrownError(_ error: Error?) {
        thrownError = error
    }

    func versionIfCached(_ id: Int) async throws -> BibleVersion? {
        nil
    }

    func version(withId id: Int) async throws -> BibleVersion {
        requestedVersionIds.append(id)
        if let thrownError {
            throw thrownError
        }
        return makeBibleVersion(id: id)
    }

    func downloadVersion(withId id: Int) async throws {
    }

    nonisolated func downloadStatus(for id: Int) -> BibleVersionRepository.BibleVersionDownloadStatus {
        .notDownloadable
    }

    func removeVersion(withId id: Int) async {
    }

    func removeUnpermittedVersions(permittedIds: Set<Int>) async {
    }
}

@MainActor
private final class MockBibleHighlightsRepository: BibleHighlightsRepositoryProtocol {
    private(set) var queuedOperations: [PendingHighlightOperation] = []

    func highlights(for references: [BibleReference]) async throws -> [String: [BibleHighlight]] {
        [:]
    }

    func queueOperation(_ operation: PendingHighlightOperation) {
        queuedOperations.append(operation)
    }
}

@MainActor
@Suite(.serialized) struct BibleReaderViewModelTests {
    private static let versionId = 3034
    private static let referenceKey = "bible-reader-view--reference"
    private static let displayIntroKey = "bible-reader-view--displayintro"
    private static let readerSettingsKey = "bible-reader-view--readersettings"

    @Test
    func initWithExplicitReferenceUsesReferenceAndHidesIntro() {
        Self.clearReaderDefaults()
        UserDefaults.standard.set(true, forKey: Self.displayIntroKey)
        let savedReference = BibleReference(versionId: 111, bookUSFM: "EXO", chapter: 3)
        UserDefaults.standard.set(try? JSONEncoder().encode(savedReference), forKey: Self.referenceKey)

        let viewModel = Self.makeViewModel(
            reference: BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 1)
        )

        #expect(viewModel.reference == BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 1))
        #expect(viewModel.showBookIntro == false)
    }

    @Test
    func initWithoutExplicitReferenceRestoresSavedReferenceAndIntroState() {
        Self.clearReaderDefaults()
        let savedReference = BibleReference(versionId: 111, bookUSFM: "EXO", chapter: 3)
        UserDefaults.standard.set(try? JSONEncoder().encode(savedReference), forKey: Self.referenceKey)
        UserDefaults.standard.set(true, forKey: Self.displayIntroKey)

        let viewModel = Self.makeViewModel(reference: nil)

        #expect(viewModel.reference == savedReference)
        #expect(viewModel.showBookIntro)
    }

    @Test
    func initWithoutSavedReferenceUsesDefaultJohnOneReference() {
        Self.clearReaderDefaults()

        let viewModel = Self.makeViewModel(reference: nil)

        #expect(viewModel.reference == BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 1))
        #expect(viewModel.showBookIntro == false)
    }

    @Test
    func referenceAndShowBookIntroPersistWhenChanged() {
        Self.clearReaderDefaults()
        let viewModel = Self.makeViewModel(reference: BibleReference(versionId: Self.versionId, bookUSFM: "GEN", chapter: 1))

        let newReference = BibleReference(versionId: Self.versionId, bookUSFM: "ROM", chapter: 8)
        viewModel.reference = newReference
        viewModel.showBookIntro = true

        let storedData = UserDefaults.standard.data(forKey: Self.referenceKey)
        let storedReference = storedData.flatMap { try? JSONDecoder().decode(BibleReference.self, from: $0) }
        #expect(storedReference == newReference)
        #expect(UserDefaults.standard.bool(forKey: Self.displayIntroKey))
    }

    @Test
    func fontControlsClampToAvailableSizesAndPersistSettings() {
        Self.clearReaderDefaults()
        let viewModel = Self.makeViewModel()

        #expect(viewModel.textOptions.fontSize == 21)

        viewModel.handleSmallerFontTap()
        #expect(viewModel.textOptions.fontSize == 18)

        viewModel.handleBiggerFontTap()
        #expect(viewModel.textOptions.fontSize == 21)

        viewModel.setFont(family: "Georgia", size: 27)
        viewModel.handleBiggerFontTap()
        #expect(viewModel.textOptions.fontFamily == "Georgia")
        #expect(viewModel.textOptions.fontSize == 27)

        let restoredViewModel = Self.makeViewModel()
        #expect(restoredViewModel.textOptions.fontFamily == "Georgia")
        #expect(restoredViewModel.textOptions.fontSize == 27)
    }

    @Test
    func openFontSettingsShowsFontSettings() {
        let viewModel = Self.makeViewModel()

        viewModel.openFontSettings()

        #expect(viewModel.showingFontSettings)
    }

    @Test
    func invalidStoredFontFallsBackToDefaultFont() {
        Self.clearReaderDefaults()
        let settings = StoredReaderSettings(fontFamily: "Definitely Not A Reader Font", fontSize: 15, lineSpacing: 18, colorTheme: 6)
        UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: Self.readerSettingsKey)

        let viewModel = Self.makeViewModel()

        #expect(viewModel.textOptions.fontFamily == ReaderFonts.defaultFontFamily)
        #expect(viewModel.textOptions.fontSize == 15)
        #expect(viewModel.textOptions.lineSpacing == 18)
        #expect(viewModel.colorTheme == ReaderTheme.theme(withId: 6))
    }

    @Test
    func colorThemeUpdatesReaderAndVersionsViewModelsAndPersists() {
        Self.clearReaderDefaults()
        let viewModel = Self.makeViewModel()
        let theme = ReaderTheme.theme(withId: 5)

        viewModel.setColorTheme(theme)

        #expect(viewModel.colorTheme == theme)
        #expect(viewModel.versionsViewModel.colorTheme == theme)
        #expect(Self.makeViewModel().colorTheme == theme)
    }

    @Test
    func selectNextLineSpacingCyclesThroughOptionsAndPersists() {
        Self.clearReaderDefaults()
        let viewModel = Self.makeViewModel()

        viewModel.selectNextLineSpacing()
        #expect(viewModel.textOptions.lineSpacing == 18)

        viewModel.selectNextLineSpacing()
        #expect(viewModel.textOptions.lineSpacing == 6)

        #expect(Self.makeViewModel().textOptions.lineSpacing == 6)
    }

    @Test
    func handleScrollShowsAndHidesChromeAroundThreshold() {
        let viewModel = Self.makeViewModel()
        viewModel.showChrome = true

        viewModel.handleScroll(offset: -5)
        #expect(viewModel.showChrome)

        viewModel.handleScroll(offset: -30)
        #expect(viewModel.showChrome == false)

        viewModel.handleScroll(offset: -25)
        #expect(viewModel.showChrome == false)

        viewModel.handleScroll(offset: -5)
        #expect(viewModel.showChrome)

        viewModel.handleScroll(offset: 0)
        #expect(viewModel.showChrome)
    }

    @Test
    func handleScrollDoesNothingWhileChangingChapter() {
        let viewModel = Self.makeViewModel()
        viewModel.isChangingChapter = true
        viewModel.lastScrollOffset = -30
        viewModel.showChrome = true

        viewModel.handleScroll(offset: -100)

        #expect(viewModel.lastScrollOffset == -30)
        #expect(viewModel.showChrome)
    }

    @Test
    func handleVerseTapWithFootnoteActionShowsFootnotes() {
        let viewModel = Self.makeViewModel()
        let reference = BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        let footnote = BibleFootnote(text: BibleAttributedString("Footnote"), reference: reference, id: "one")

        viewModel.handleVerseTap(
            reference: reference,
            actionType: BibleVersionRendering.LinkSchemes.footnote.rawValue,
            footnotes: [footnote]
        )

        #expect(viewModel.showingFootnotes)
        #expect(viewModel.footnotesToDisplay == [footnote])
    }

    @Test
    func handleVerseTapUsesCustomVerseTapHandlerBeforeSelection() {
        let reference = BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        var tappedReference: BibleReference?
        let viewModel = Self.makeViewModel(onVerseTap: { tappedReference = $0 })

        viewModel.handleVerseTap(reference: reference, actionType: "", footnotes: [])

        #expect(tappedReference == reference)
        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
    }

    @Test
    func handleVerseTapPromptsForSignInWhenUnsignedOutAndSignInEnabled() {
        Self.clearReaderDefaults()
        YouVersionPlatformConfiguration.clearAuthTokens()
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: true)
        let viewModel = Self.makeViewModel()

        viewModel.handleVerseTap(
            reference: BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 16),
            actionType: "",
            footnotes: []
        )

        #expect(viewModel.showingSignInSheet)
        #expect(viewModel.selectedVerses.isEmpty)
    }

    @Test
    func handleVerseTapDoesNothingWhenUnsignedOutAndSignInDisabled() {
        Self.clearReaderDefaults()
        YouVersionPlatformConfiguration.clearAuthTokens()
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: false)
        let viewModel = Self.makeViewModel()

        viewModel.handleVerseTap(
            reference: BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 16),
            actionType: "",
            footnotes: []
        )

        #expect(viewModel.showingSignInSheet == false)
        #expect(viewModel.selectedVerses.isEmpty)
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: true)
    }

    @Test
    func handleVerseTapTogglesSelectionWhenSignedIn() {
        Self.clearReaderDefaults()
        YouVersionPlatformConfiguration.saveAuthData(
            accessToken: "access-token",
            refreshToken: nil,
            idToken: nil,
            expiryDate: nil
        )
        let viewModel = Self.makeViewModel()
        let reference = BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)

        viewModel.handleVerseTap(reference: reference, actionType: "", footnotes: [])

        #expect(viewModel.selectedVerses == [reference])
        #expect(viewModel.showingVerseActionsDrawer)

        viewModel.handleVerseTap(reference: reference, actionType: "", footnotes: [])

        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
        YouVersionPlatformConfiguration.clearAuthTokens()
    }

    @Test
    func removeVerseSelectionClearsSelectionAndHidesDrawer() {
        let viewModel = Self.makeViewModel()
        viewModel.selectedVerses = [
            BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 16),
        ]
        viewModel.showingVerseActionsDrawer = true

        viewModel.removeVerseSelection()

        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
    }

    @Test
    func addAndRemoveVerseColorUpdateHighlightsForSelectedVerses() {
        Self.clearReaderDefaults()
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Self.makeViewModel(highlightsRepository: highlightsRepository)
        let firstReference = BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        let secondReference = BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 17)
        let color = Color(hex: "#DDAAFF")
        viewModel.selectedVerses = [firstReference, secondReference]

#if canImport(UIKit)
        viewModel.addVerseColor(color)

        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
        #expect(viewModel.highlightsViewModel.highlights(for: firstReference) == [BibleHighlight(firstReference, color: "DDAAFF")])
        #expect(viewModel.highlightsViewModel.highlights(for: secondReference) == [BibleHighlight(secondReference, color: "DDAAFF")])
        #expect(highlightsRepository.queuedOperations.first?.operationType == .add)

        viewModel.selectedVerses = [firstReference, secondReference]
        #expect(viewModel.isColorPresentOnAnySelectedVerses(color))
        #expect(viewModel.isColorPresentOnAllSelectedVerses(color))

        viewModel.removeVerseColor(color)

        #expect(viewModel.highlightsViewModel.highlights(for: firstReference).isEmpty)
        #expect(viewModel.highlightsViewModel.highlights(for: secondReference).isEmpty)
        #expect(highlightsRepository.queuedOperations.last?.operationType == .remove)
#else
        viewModel.addVerseColor(color)

        #expect(viewModel.selectedVerses == [firstReference, secondReference])
        #expect(viewModel.highlightsViewModel.highlights(for: firstReference).isEmpty)
        #expect(viewModel.highlightsViewModel.highlights(for: secondReference).isEmpty)
        #expect(highlightsRepository.queuedOperations.isEmpty)
#endif
    }

    @Test
    func shareableURLAndTitleUsesMergedSelectionAndCurrentVersion() throws {
        let viewModel = Self.makeViewModel()
        let version = Self.makeBibleVersion(id: Self.versionId)
        viewModel.versionsViewModel.switchToVersion(version)
        viewModel.selectedVerses = [
            BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 17),
            BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 16),
        ]

        let result = try #require(viewModel.shareableURLAndTitleForSelection)

        #expect(result.0.absoluteString == "https://www.bible.com/bible/3034/JHN.3.16-17.TST")
        #expect(result.1 == "John 3:16-17 TST")
    }

    @Test
    func shareableURLAndTitleReturnsNilWithoutVersionOrReferences() {
        let viewModel = Self.makeViewModel()

        #expect(viewModel.shareableURLAndTitleForSelection == nil)

        viewModel.versionsViewModel.switchToVersion(Self.makeBibleVersion(id: Self.versionId))
        #expect(viewModel.shareableURLAndTitleFor(references: []) == nil)
    }

    @Test
    func shareableVerseTextReturnsEmptyStringForEmptySelection() async {
        let viewModel = Self.makeViewModel()

        let text = await viewModel.shareableVerseText(references: [])

        #expect(text == "")
    }

    @Test
    func handleVerseActionCopyWithEmptySelectionDoesNothing() {
        let viewModel = Self.makeViewModel()
        viewModel.showingVerseActionsDrawer = true

        viewModel.handleVerseActionCopy()

        #expect(viewModel.showingVerseActionsDrawer)
        #expect(viewModel.selectedVerses.isEmpty)
    }

    @Test
    func onHeaderSelectionChangeUpdatesReferenceAndResetsReaderState() async {
        let repository = MockBibleVersionRepository()
        let viewModel = Self.makeViewModel(versionRepository: repository)
        viewModel.versionsViewModel.switchToVersion(Self.makeBibleVersion(id: Self.versionId))
        let selectedReference = BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 1, verse: 1)
        viewModel.selectedVerses = [selectedReference]
        viewModel.showingVerseActionsDrawer = true
        viewModel.showChrome = false
        viewModel.lastScrollOffset = -100

        let newReference = BibleReference(versionId: 111, bookUSFM: "JHN", chapter: 3)
        await viewModel.onHeaderSelectionChange(newReference, showIntro: true)

        #expect(viewModel.reference == newReference)
        #expect(viewModel.showBookIntro)
        #expect(viewModel.versionsViewModel.currentVersion == Self.makeBibleVersion(id: 111))
        #expect(viewModel.versionsViewModel.myVersions.contains(Self.makeBibleVersion(id: 111)))
        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
        #expect(viewModel.showChrome)
        #expect(viewModel.lastScrollOffset == 0)
        #expect(viewModel.scrollToTop)
        #expect(await repository.requestedIds() == [111])
    }

    @Test
    func onHeaderSelectionChangeDoesNotMutateStateWhenRepositoryThrows() async {
        let repository = MockBibleVersionRepository()
        await repository.setThrownError(TestError())
        let originalReference = BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 1)
        let viewModel = Self.makeViewModel(reference: originalReference, versionRepository: repository)
        viewModel.versionsViewModel.switchToVersion(Self.makeBibleVersion(id: Self.versionId))

        await viewModel.onHeaderSelectionChange(BibleReference(versionId: 111, bookUSFM: "JHN", chapter: 3), showIntro: true)

        #expect(viewModel.reference == originalReference)
        #expect(viewModel.showBookIntro == false)
        #expect(await repository.requestedIds() == [111])
    }

    @Test
    func handleVersionPickedNoOpsWhenVersionIsUnchanged() async {
        let viewModel = Self.makeViewModel()
        let selectedReference = BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 1, verse: 1)
        viewModel.versionsViewModel.switchToVersion(Self.makeBibleVersion(id: Self.versionId))
        viewModel.selectedVerses = [selectedReference]
        viewModel.showingVerseActionsDrawer = true

        viewModel.handleVersionPicked(Self.makeBibleVersion(id: Self.versionId))
        await Self.allowPendingTasksToRun()

        #expect(viewModel.reference == BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 1))
        #expect(viewModel.selectedVerses == [selectedReference])
        #expect(viewModel.showingVerseActionsDrawer)
    }

    @Test
    func handleVersionPickedUpdatesReferenceVersionAndLoadsSelection() async {
        let repository = MockBibleVersionRepository()
        let viewModel = Self.makeViewModel(versionRepository: repository)

        viewModel.handleVersionPicked(Self.makeBibleVersion(id: 111))
        await Self.waitUntil { viewModel.versionsViewModel.currentVersion != nil }

        #expect(viewModel.reference == BibleReference(versionId: 111, bookUSFM: "JHN", chapter: 1))
        #expect(viewModel.versionsViewModel.currentVersion == Self.makeBibleVersion(id: 111))
        #expect(await repository.requestedIds() == [111])
    }

    @Test
    func versionsSignInCallbackStartsSignInFlow() {
        let viewModel = Self.makeViewModel()

        viewModel.versionsViewModel.onSignInRequired?()

        #expect(viewModel.startSignInFlow)
    }

    @Test
    func signInStartsFlowOnlyWhenSignedOut() {
        Self.clearReaderDefaults()
        YouVersionPlatformConfiguration.clearAuthTokens()
        let viewModel = Self.makeViewModel()

        viewModel.signIn()
        #expect(viewModel.startSignInFlow)

        viewModel.startSignInFlow = false
        YouVersionPlatformConfiguration.saveAuthData(
            accessToken: "access-token",
            refreshToken: nil,
            idToken: nil,
            expiryDate: nil
        )

        viewModel.signIn()

        #expect(viewModel.startSignInFlow == false)
        YouVersionPlatformConfiguration.clearAuthTokens()
    }

    @Test
    func signOutShowsConfirmationAndConfirmSignOutClearsAuthAndHighlights() {
        Self.clearReaderDefaults()
        YouVersionPlatformConfiguration.saveAuthData(
            accessToken: "access-token",
            refreshToken: nil,
            idToken: nil,
            expiryDate: nil
        )
        let viewModel = Self.makeViewModel()
        let reference = BibleReference(versionId: Self.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.highlightsViewModel.addHighlights(references: [reference], color: "DDAAFF")

        viewModel.signOut()
        #expect(viewModel.showSignOutConfirmation)

        viewModel.confirmSignOut()

        #expect(YouVersionAPI.isSignedIn == false)
        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
    }

    @Test
    func updateSignInStateUsesCurrentTokenState() async {
        Self.clearReaderDefaults()
        let viewModel = Self.makeViewModel()
        YouVersionPlatformConfiguration.saveAuthData(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            idToken: nil,
            expiryDate: Date().addingTimeInterval(60)
        )

        viewModel.updateSignInState()
        await Self.waitUntil { viewModel.isSignedIn }

        #expect(viewModel.isSignedIn)
        YouVersionPlatformConfiguration.clearAuthTokens()
    }

    private static func makeViewModel(
        reference: BibleReference? = BibleReference(versionId: versionId, bookUSFM: "JHN", chapter: 1),
        highlightsRepository: MockBibleHighlightsRepository = MockBibleHighlightsRepository(),
        versionRepository: any BibleVersionRepositoryProtocol = MockBibleVersionRepository(),
        onVerseTap: ((BibleReference) -> Void)? = nil
    ) -> BibleReaderViewModel {
        let highlightsViewModel = BibleHighlightsViewModel(
            cache: BibleHighlightsCache(),
            repository: highlightsRepository
        )
        let versionsViewModel = BibleVersionsViewModel(versionRepository: versionRepository)
        return BibleReaderViewModel(
            reference: reference,
            highlightsViewModel: highlightsViewModel,
            versionsViewModel: versionsViewModel,
            onVerseTap: onVerseTap
        )
    }

    fileprivate static func makeBibleVersion(id: Int) -> BibleVersion {
        BibleVersion(
            id: id,
            abbreviation: "TEST",
            promotionalContent: nil,
            copyright: nil,
            languageTag: "en",
            localizedAbbreviation: "TST",
            localizedTitle: "Test Version",
            readerFooter: nil,
            readerFooterUrl: nil,
            title: "Test Version",
            organizationId: nil,
            bookCodes: ["JHN"],
            books: [
                BibleBook(
                    id: "JHN",
                    title: "John",
                    fullTitle: "John",
                    abbreviation: "John",
                    canon: "nt",
                    chapters: (1...3).map { chapter in
                        BibleChapter(id: "JHN.\(chapter)", passageId: nil, title: "\(chapter)", verses: nil)
                    },
                    intro: nil
                ),
            ],
            textDirection: "ltr"
        )
    }

    private static func clearReaderDefaults() {
        UserDefaults.standard.removeObject(forKey: Self.referenceKey)
        UserDefaults.standard.removeObject(forKey: Self.displayIntroKey)
        UserDefaults.standard.removeObject(forKey: Self.readerSettingsKey)
    }

    private static func allowPendingTasksToRun() async {
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }

    private static func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<10 where !condition() {
            await Task.yield()
        }
    }
}

private struct TestError: Error {}

private struct StoredReaderSettings: Codable {
    let fontFamily: String?
    let fontSize: CGFloat?
    let lineSpacing: CGFloat?
    let colorTheme: Int?
}

private func makeBibleVersion(id: Int) -> BibleVersion {
    BibleVersion(
        id: id,
        abbreviation: "TEST",
        promotionalContent: nil,
        copyright: nil,
        languageTag: "en",
        localizedAbbreviation: "TST",
        localizedTitle: "Test Version",
        readerFooter: nil,
        readerFooterUrl: nil,
        title: "Test Version",
        organizationId: nil,
        bookCodes: ["JHN"],
        books: [
            BibleBook(
                id: "JHN",
                title: "John",
                fullTitle: "John",
                abbreviation: "John",
                canon: "nt",
                chapters: (1...3).map { chapter in
                    BibleChapter(id: "JHN.\(chapter)", passageId: nil, title: "\(chapter)", verses: nil)
                },
                intro: nil
            ),
        ],
        textDirection: "ltr"
    )
}
