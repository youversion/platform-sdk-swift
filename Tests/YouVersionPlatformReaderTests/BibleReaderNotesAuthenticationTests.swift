import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
struct BibleReaderNotesAuthenticationTests {
    private let reference = BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16)

    @Test
    func signedOutSaveDefersComposerUntilHighlightsPermissionIsGranted() throws {
        let state = MockBibleReaderAuthenticationState(isSignedIn: false)
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(readIsSignedIn: { state.isSignedIn })
        viewModel.selectedVerses = [reference]
        viewModel.showingVerseActionsDrawer = true
        viewModel.startNote()
        let capturedDraft = try #require(viewModel.pendingNoteDraft)
        #expect(viewModel.showingSignInSheet)
        #expect(!viewModel.showingVerseActionsDrawer)
        #expect(viewModel.noteDraft == nil)

        viewModel.signIn()
        viewModel.cancelSignInPrompt()
        #expect(viewModel.pendingNoteDraft === capturedDraft)
        viewModel.selectedVerses = []
        state.isSignedIn = true
        viewModel.completeSignInFlow(with: ["highlights"])

        #expect(viewModel.noteDraft === capturedDraft)
        #expect(viewModel.noteDraft?.references == [reference])
        #expect(viewModel.pendingNoteDraft == nil)
    }

    @Test(arguments: [[String](), ["read_notes"], ["write_notes"]])
    func signInWithoutHighlightsDoesNotOpenComposer(permissions: [String]) {
        let state = MockBibleReaderAuthenticationState(isSignedIn: false)
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(readIsSignedIn: { state.isSignedIn })
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        state.isSignedIn = true
        viewModel.completeSignInFlow(with: permissions)

        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft == nil)
        #expect(viewModel.selectedVerses == [reference])
        #expect(viewModel.showingVerseActionsDrawer)
    }

    @Test
    func cancellingSignInPromptDoesNotOpenComposerAfterALaterLogin() {
        let state = MockBibleReaderAuthenticationState(isSignedIn: false)
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(readIsSignedIn: { state.isSignedIn })
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        viewModel.cancelSignInPrompt()
        state.isSignedIn = true
        viewModel.completeSignInFlow(with: ["highlights"])

        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft == nil)
        #expect(viewModel.selectedVerses == [reference])
    }

    @Test
    func highlightsPermissionWithoutSuccessfulSignInCannotOpenComposer() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel()
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        viewModel.completeSignInFlow(with: ["highlights"])
        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft == nil)
    }

    @Test(arguments: [true, false])
    func signedInUserWithoutHighlightsRequestsConsentBeforeOpeningComposer(isGranted: Bool) {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == YouVersionAPI.Users.readNotesPermission }
        )
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        #expect(viewModel.startDataExchangeFlow)
        #expect(!viewModel.showingSignInSheet)
        #expect(viewModel.noteDraft == nil)

        viewModel.completeDataExchangeFlow(with: isGranted ? ["highlights"] : [])

        #expect((viewModel.noteDraft != nil) == isGranted)
        #expect(viewModel.pendingNoteDraft == nil)
        #expect(!viewModel.startDataExchangeFlow)
    }

    @Test
    func signedInUserWithHighlightsOpensComposerWithoutNotesPermission() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == "highlights" }
        )
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        #expect(viewModel.noteDraft != nil)
        #expect(!viewModel.showingSignInSheet)
        #expect(!viewModel.startDataExchangeFlow)
    }

    @Test
    func betaNotesUsesOnlyHighlightsForConsent() {
        #expect(BibleReaderViewModel.notesPermission == "highlights")
        #expect(BibleReaderViewModel.dataExchangePermissions == ["highlights"])
        #expect(BibleReaderViewModel.signInPermissions.contains("highlights"))
        #expect(!BibleReaderViewModel.signInPermissions.contains(YouVersionAPI.Users.readNotesPermission))
        #expect(!BibleReaderViewModel.signInPermissions.contains(YouVersionAPI.Users.writeNotesPermission))
    }
}
