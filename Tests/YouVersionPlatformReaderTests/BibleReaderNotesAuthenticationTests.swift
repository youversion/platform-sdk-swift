import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
struct BibleReaderNotesAuthenticationTests {
    private let reference = BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16)

    @Test
    func signedOutSaveDefersComposerUntilWriteNotesScopeIsGranted() throws {
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
        viewModel.completeSignInFlow(with: ["write_notes"])

        #expect(viewModel.noteDraft === capturedDraft)
        #expect(viewModel.noteDraft?.references == [reference])
        #expect(viewModel.pendingNoteDraft == nil)
    }

    @Test(arguments: [[String](), ["read_notes"], ["highlights"]])
    func signInWithoutWriteNotesDoesNotOpenComposer(permissions: [String]) {
        let state = MockBibleReaderAuthenticationState(isSignedIn: false)
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(readIsSignedIn: { state.isSignedIn })
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        state.isSignedIn = true
        viewModel.completeSignInFlow(with: permissions)

        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft != nil)
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
        viewModel.completeSignInFlow(with: ["write_notes"])

        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft != nil)
        #expect(viewModel.selectedVerses == [reference])
    }

    @Test
    func writeNotesScopeWithoutSuccessfulSignInCannotOpenComposer() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel()
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        viewModel.completeSignInFlow(with: ["write_notes"])
        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft != nil)
    }

    @Test(arguments: [true, false])
    func signedInUserWithoutWriteNotesRequestsOAuthBeforeOpeningComposer(isGranted: Bool) {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == YouVersionAPI.Users.readNotesPermission }
        )
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        #expect(viewModel.startSignInFlow)
        #expect(!viewModel.startDataExchangeFlow)
        #expect(!viewModel.showingSignInSheet)
        #expect(viewModel.noteDraft == nil)

        viewModel.completeSignInFlow(with: isGranted ? ["write_notes"] : [])

        #expect((viewModel.noteDraft != nil) == isGranted)
        #expect((viewModel.pendingNoteDraft == nil) == isGranted)
        #expect(!viewModel.startDataExchangeFlow)
    }

    @Test
    func signedInUserWithWriteNotesOpensComposerWithoutHighlights() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == YouVersionAPI.Users.writeNotesPermission }
        )
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        #expect(viewModel.noteDraft != nil)
        #expect(!viewModel.showingSignInSheet)
        #expect(!viewModel.startDataExchangeFlow)
    }

    @Test(arguments: [false, true])
    func disabledSignInAllowsOnlyAlreadyAuthorizedNotes(hasWritePermission: Bool) {
        let appKey = YouVersionPlatformConfiguration.appKey
        let apiHost = YouVersionPlatformConfiguration.apiHost
        let appName = YouVersionPlatformConfiguration.appName
        let prompt = YouVersionPlatformConfiguration.signInPromptMessage
        let wasEnabled = YouVersionPlatformConfiguration.isSignInEnabled
        let languageTags = YouVersionPlatformConfiguration.permittedLanguageTags
        let versionIDs = YouVersionPlatformConfiguration.permittedVersionIds
        let excludedIDs = YouVersionPlatformConfiguration.excludedVersionIds
        defer {
            YouVersionPlatformConfiguration.configure(
                appKey: appKey, apiHost: apiHost, appName: appName, isSignInEnabled: wasEnabled,
                signInPromptMessage: prompt, permittedLanguageTags: languageTags,
                permittedVersionIds: versionIDs, excludedVersionIds: excludedIDs
            )
        }
        YouVersionPlatformConfiguration.configure(appKey: appKey, isSignInEnabled: false)
        let model = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { hasWritePermission && $0 == "write_notes" }
        )
        model.selectedVerses = [reference]
        model.startNote()

        #expect((model.noteDraft != nil) == hasWritePermission)
        #expect(model.pendingNoteDraft == nil)
        #expect(!model.isNoteAuthorizationPending)
        #expect(!model.startSignInFlow)
        #expect(!model.showingSignInSheet)
    }

    @Test
    func dataExchangeGrantCannotReplaceOAuthNotesConsent() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == "highlights" }
        )
        viewModel.selectedVerses = [reference]
        viewModel.startNote()
        let draft = viewModel.pendingNoteDraft
        #expect(draft != nil)
        #expect(viewModel.startSignInFlow)
        viewModel.completeDataExchangeFlow(with: ["highlights", "write_notes"])
        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft === draft)
        viewModel.completeSignInFlow(with: ["read_notes", "write_notes"])
        #expect(viewModel.noteDraft === draft)
        #expect(viewModel.pendingNoteDraft == nil)
    }

    @Test
    func notesScopesAreRequestedThroughOAuthRatherThanDataExchange() {
        #expect(BibleReaderViewModel.notesPermission == YouVersionAPI.Users.writeNotesPermission)
        #expect(BibleReaderViewModel.dataExchangePermissions == ["highlights"])
        #expect(BibleReaderViewModel.signInPermissions.contains("highlights"))
        #expect(BibleReaderViewModel.signInPermissions.contains(YouVersionAPI.Users.readNotesPermission))
        #expect(BibleReaderViewModel.signInPermissions.contains(YouVersionAPI.Users.writeNotesPermission))
    }
}
