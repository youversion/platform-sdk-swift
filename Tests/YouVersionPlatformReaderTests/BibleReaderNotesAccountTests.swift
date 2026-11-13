import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
struct BibleReaderNotesAccountTests {
    private let reference = BibleReference(versionId: 3034, bookId: "GEN", chapter: 1, verse: 3)

    private func savedNote() throws -> YouVersionNote {
        try JSONDecoder().decode(YouVersionNote.self, from: Data("""
        {"id":"private-note","content":"Private reflection","status":"private",
         "passage":{"bible_id":3034,"passage_id":"GEN.1.3"}}
        """.utf8))
    }

    @Test(arguments: [false, true])
    func accountChangeOrSignOutRemovesOpenAndPendingPrivateDrafts(signOut: Bool) throws {
        let owner = AccountState()
        let auth = MockBibleReaderAuthenticationState(isSignedIn: true)
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            readIsSignedIn: { auth.isSignedIn }, hasPermission: { _ in true }
        )
        let draft = BibleReaderNoteDraft(
            references: [reference], referenceTitle: "Genesis 1:3", savedNotes: [try savedNote()], account: { owner.value }
        )
        draft.copyText(from: try savedNote())
        viewModel.noteDraft = draft
        viewModel.pendingNoteDraft = draft
        viewModel.isNoteAuthorizationPending = true
        owner.value = owner.otherAccount(signOut: signOut)
        auth.isSignedIn = !signOut
        viewModel.notesAuthorizationDidChange()
        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft == nil)
        #expect(!viewModel.isNoteAuthorizationPending)
        #expect(draft.savedNotes.isEmpty)
        #expect(draft.content.isEmpty)
        #expect(!draft.canSave)
        #expect(!draft.showingDiscardConfirmation)
    }

    @Test
    func sameAccountCredentialRefreshPreservesOpenDraft() throws {
        let owner = AccountState()
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(isSignedIn: true, hasPermission: { _ in true })
        let draft = BibleReaderNoteDraft(
            references: [reference], referenceTitle: "Genesis 1:3", savedNotes: [try savedNote()], account: { owner.value }
        )
        draft.content = "Unsaved text"
        viewModel.noteDraft = draft
        viewModel.notesAuthorizationDidChange()
        #expect(viewModel.noteDraft === draft)
        #expect(draft.content == "Unsaved text")
        #expect(draft.savedNotes.count == 1)
    }

    @Test(arguments: [(false, false, false), (false, false, true), (false, true, false), (false, true, true),
                      (true, false, false), (true, false, true), (true, true, false), (true, true, true)])
    func delayedSaveOrDeleteCannotAffectTheNextAccount(isDelete: Bool, fails: Bool, signOut: Bool) async throws {
        let owner = AccountState()
        let auth = MockBibleReaderAuthenticationState(isSignedIn: true)
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            readIsSignedIn: { auth.isSignedIn }, hasPermission: { _ in true }
        )
        let note = try savedNote()
        var completion: CheckedContinuation<Void, any Error>?
        func holdRequest() async throws {
            try await withCheckedThrowingContinuation { completion = $0 }
        }
        let draft = BibleReaderNoteDraft(
            references: [reference], referenceTitle: "Genesis 1:3", savedNotes: [note],
            createNote: { _ in try await holdRequest() }, deleteNote: { _ in try await holdRequest() }, account: { owner.value }
        )
        draft.content = "New text"
        viewModel.noteDraft = draft
        let operation = Task { isDelete ? await draft.delete(note) : await draft.save() }
        while completion == nil { await Task.yield() }
        owner.value = owner.otherAccount(signOut: signOut)
        auth.isSignedIn = !signOut
        viewModel.notesAuthorizationDidChange()
        let nextDraft = BibleReaderNoteDraft(references: [reference], referenceTitle: "Next account", account: { owner.value })
        viewModel.noteDraft = nextDraft
        if fails { completion?.resume(throwing: URLError(.notConnectedToInternet)) } else { completion?.resume() }
        #expect(await operation.value == false)
        #expect(viewModel.noteDraft === nextDraft)
        #expect(nextDraft.content.isEmpty)
        #expect(draft.savedNotes.isEmpty)
        #expect(!draft.showingSaveError)
    }

    @Test(arguments: [false, true])
    func delayedAuthorizationDoesNotSendSaveOrDeleteForAnotherAccount(isDelete: Bool) async throws {
        let owner = AccountState()
        let note = try savedNote()
        var requests = 0
        var completion: CheckedContinuation<Void, Never>?
        let draft = BibleReaderNoteDraft(
            references: [reference], referenceTitle: "Genesis 1:3", savedNotes: [note],
            createNote: { _ in requests += 1 }, deleteNote: { _ in requests += 1 }, account: { owner.value }
        )
        draft.content = "New text"
        func authorize() async { await withCheckedContinuation { completion = $0 } }
        let operation = Task { isDelete ? await draft.delete(note, authorize: authorize) : await draft.save(authorize: authorize) }
        while completion == nil { await Task.yield() }
        owner.value = owner.otherAccount(signOut: false)
        completion?.resume()
        #expect(await operation.value == false)
        #expect(requests == 0)
    }

    @Test(arguments: [false, true], [false, true])
    func delayedSignInCannotResumeAnotherAccountsPendingDraft(duringValidation: Bool, signOut: Bool) async {
        let owner = AccountState()
        let auth = MockBibleReaderAuthenticationState(isSignedIn: true)
        var validation: CheckedContinuation<Bool, Never>?
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            readIsSignedIn: { auth.isSignedIn },
            validateToken: { await withCheckedContinuation { validation = $0 } }, hasPermission: { _ in true }
        )
        let draft = BibleReaderNoteDraft(references: [reference], referenceTitle: "First account", account: { owner.value })
        viewModel.pendingNoteDraft = draft
        viewModel.isNoteAuthorizationPending = true
        let oldRequestID = viewModel.signInRequestID
        var completion: Task<Void, Never>?
        if duringValidation {
            completion = Task { await viewModel.completeSignInFlow(with: ["write_notes"], requestID: oldRequestID) }
            while validation == nil { await Task.yield() }
        }
        owner.value = owner.otherAccount(signOut: signOut)
        auth.isSignedIn = !signOut
        viewModel.notesAuthorizationDidChange()
        let nextDraft = BibleReaderNoteDraft(references: [reference], referenceTitle: "Next account", account: { owner.value })
        viewModel.pendingNoteDraft = nextDraft
        viewModel.isNoteAuthorizationPending = true
        if duringValidation {
            validation?.resume(returning: true)
            await completion?.value
        } else {
            await viewModel.completeSignInFlow(with: ["write_notes"], requestID: oldRequestID)
        }
        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft === nextDraft)
    }

    @Test
    func lateConsentCannotRestoreAnotherAccountsSelectionBeforeNotification() {
        let owner = AccountState()
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(isSignedIn: true, hasPermission: { _ in true })
        let draft = BibleReaderNoteDraft(references: [reference], referenceTitle: "First account", account: { owner.value })
        viewModel.pendingNoteDraft = draft
        viewModel.isNoteAuthorizationPending = true
        owner.value = owner.otherAccount(signOut: false)
        viewModel.selectedVerses = []
        viewModel.continuePendingNote(with: ["write_notes"])
        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.pendingNoteDraft == nil)
        #expect(viewModel.selectedVerses.isEmpty)
        #expect(!viewModel.showingVerseActionsDrawer)
    }

    @Test
    func retryingAPreSignInDraftBindsItToTheSignedInUser() {
        let owner = AccountState()
        owner.value = owner.otherAccount(signOut: true)
        let draft = BibleReaderNoteDraft(references: [reference], referenceTitle: "Before sign-in", account: { owner.value })
        draft.content = "Retained text"
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(isSignedIn: true, hasPermission: { _ in true })
        viewModel.pendingNoteDraft = draft
        viewModel.selectedVerses = [reference]
        owner.value = owner.otherAccount(signOut: false)
        viewModel.startNote()
        #expect(viewModel.noteDraft === draft)
        #expect(draft.canSave)
        #expect(draft.content == "Retained text")
    }

    @Test
    func losingReadScopeRemovesCopiedSavedNotes() throws {
        let owner = AccountState()
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(isSignedIn: true, hasPermission: { _ in false })
        let draft = BibleReaderNoteDraft(
            references: [reference], referenceTitle: "Genesis 1:3", savedNotes: [try savedNote()], account: { owner.value }
        )
        viewModel.noteDraft = draft
        viewModel.notesAuthorizationDidChange()
        #expect(viewModel.noteDraft == nil)
        #expect(draft.savedNotes.isEmpty)
    }

    @Test(arguments: [false, true], [false, true])
    func disabledSignInRequiresExistingAuthenticationAndWriteScope(isSignedIn: Bool, hasWriteScope: Bool) {
        let wasEnabled = YouVersionPlatformConfiguration.isSignInEnabled
        func configure(signInEnabled: Bool) {
            YouVersionPlatformConfiguration.configure(
                appKey: YouVersionPlatformConfiguration.appKey, apiHost: YouVersionPlatformConfiguration.apiHost,
                appName: YouVersionPlatformConfiguration.appName, isSignInEnabled: signInEnabled,
                signInPromptMessage: YouVersionPlatformConfiguration.signInPromptMessage,
                permittedLanguageTags: YouVersionPlatformConfiguration.permittedLanguageTags,
                permittedVersionIds: YouVersionPlatformConfiguration.permittedVersionIds,
                excludedVersionIds: YouVersionPlatformConfiguration.excludedVersionIds
            )
        }
        configure(signInEnabled: false)
        defer { configure(signInEnabled: wasEnabled) }
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(isSignedIn: isSignedIn, hasPermission: { _ in hasWriteScope })
        viewModel.selectedVerses = [reference]
        viewModel.showingVerseActionsDrawer = true
        viewModel.startNote()
        #expect((viewModel.noteDraft != nil) == (isSignedIn && hasWriteScope))
        #expect(viewModel.pendingNoteDraft == nil)
        #expect(!viewModel.startSignInFlow)
        #expect(!viewModel.showingSignInSheet)
        #expect(!viewModel.startDataExchangeFlow)
        #expect(viewModel.selectedVerses == [reference])
    }
}

@MainActor
private final class AccountState {
    var value = BibleNotesAccount(userID: "account-a", appKey: "fixture-app", apiHost: "api.example.com")

    func otherAccount(signOut: Bool) -> BibleNotesAccount {
        BibleNotesAccount(userID: signOut ? nil : "account-b", appKey: value.appKey, apiHost: value.apiHost)
    }
}
