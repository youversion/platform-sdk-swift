import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
struct BibleReaderNoteAccountTests {
    private let reference = BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16)

    @Test(arguments: [false, true])
    func logoutAndAccountReplacementClearTheOpenDraft(isReplacement: Bool) throws {
        let state = NoteAccountState()
        let model = makeViewModel(state: state)
        let note = try savedNote()
        model.showNotes(for: reference, notes: [note])
        let draft = try #require(model.noteDraft)
        draft.copyText(from: note)
        draft.isPublic = true
        draft.colorHex = "ffec5b"

        state.account = isReplacement ? BibleReaderViewModelTestSupport.makeAccount(userID: "second-user") : nil
        model.notesAuthenticationDidChange()

        #expect(model.noteDraft == nil)
        #expect(draft.isInvalidated)
        #expect(draft.savedNotes.isEmpty)
        #expect(draft.content.isEmpty)
        #expect(!draft.isPublic)
        #expect(draft.colorHex == nil)
        #expect(!draft.canSave)
    }

    @Test(arguments: [false, true])
    func logoutAndAccountReplacementInvalidatePendingAuthorization(isReplacement: Bool) throws {
        let state = NoteAccountState()
        let model = makeViewModel(state: state)
        model.selectedVerses = [reference]
        model.startNote()
        let draft = try #require(model.pendingNoteDraft)
        draft.content = "Private reflection"

        state.account = isReplacement ? BibleReaderViewModelTestSupport.makeAccount(userID: "second-user") : nil
        model.notesAuthenticationDidChange()
        model.completeSignInFlow(with: ["write_notes"])

        #expect(model.pendingNoteDraft == nil)
        #expect(!model.isNoteAuthorizationPending)
        #expect(model.noteDraft == nil)
        #expect(draft.isInvalidated)
        #expect(draft.content.isEmpty)
    }

    @Test
    func refreshingTheSameAccountPreservesItsDraft() throws {
        let state = NoteAccountState()
        let model = makeViewModel(state: state)
        model.showNotes(for: reference, notes: [try savedNote()])
        let draft = try #require(model.noteDraft)
        draft.content = "Keep this reflection"

        state.account = BibleReaderViewModelTestSupport.makeAccount(userID: "first-user", accessToken: "refreshed-token")
        model.notesAuthenticationDidChange()

        #expect(model.noteDraft === draft)
        #expect(!draft.isInvalidated)
        #expect(draft.content == "Keep this reflection")
        #expect(!draft.savedNotes.isEmpty)
    }

    @Test
    func signedOutSelectionBindsToTheAccountThatAuthorizesIt() throws {
        let state = NoteAccountState()
        state.account = nil
        let model = makeViewModel(state: state)
        model.selectedVerses = [reference]
        model.startNote()
        let draft = try #require(model.pendingNoteDraft)

        state.account = BibleReaderViewModelTestSupport.makeAccount(userID: "first-user")
        model.notesAuthenticationDidChange()
        model.completeSignInFlow(with: ["write_notes"])

        #expect(model.noteDraft === draft)
        #expect(draft.account == state.account)
        #expect(draft.canSave)
        model.confirmSignOut()
        #expect(model.noteDraft == nil)
        #expect(draft.isInvalidated)
    }

    @Test(arguments: [false, true], [false, true])
    func invalidationCancelsMutationsAndIgnoresLateResults(isDelete: Bool, isAuthorizing: Bool) async throws {
        let state = NoteAccountState()
        let note = try savedNote()
        var continuation: CheckedContinuation<Void, Never>?
        var didSendRequest = false
        var observedCancellation = false
        @MainActor @Sendable func suspendOperation() async {
            await withCheckedContinuation { continuation = $0 }
            observedCancellation = Task.isCancelled
        }
        @MainActor @Sendable func mutate() async {
            didSendRequest = true
            if !isAuthorizing {
                await suspendOperation()
            }
        }
        @MainActor @Sendable func authorize() async throws {
            if isAuthorizing {
                await suspendOperation()
            }
        }
        let draft = BibleReaderNoteDraft(
            references: [reference], referenceTitle: "John 3:16", savedNotes: [note],
            account: state.account, currentAccount: { state.account },
            createNote: { _ in await mutate() }, deleteNote: { _ in await mutate() }
        )
        draft.content = "Private reflection"
        let task = Task {
            if isDelete {
                return await draft.delete(note, authorize: authorize)
            }
            return await draft.save(authorize: authorize)
        }
        for _ in 0..<1000 where continuation == nil { await Task.yield() }
        let resume = try #require(continuation)
        state.account = BibleReaderViewModelTestSupport.makeAccount(userID: "second-user")
        draft.invalidate()
        resume.resume()

        #expect(await task.value == false)
        #expect(observedCancellation)
        #expect(didSendRequest == !isAuthorizing)
        #expect(draft.savedNotes.isEmpty)
        #expect(draft.content.isEmpty)
        #expect(!draft.isBusy)
        #expect(!draft.showingSaveError)
        #expect(await draft.save() == false)
        #expect(await draft.delete(note) == false)
    }

    @Test
    func authorizationCannotMoveADraftToAnotherAccountWithoutANotification() async {
        let state = NoteAccountState()
        var didCreate = false
        let draft = BibleReaderNoteDraft(
            references: [reference], referenceTitle: "John 3:16",
            account: state.account, currentAccount: { state.account }, createNote: { _ in didCreate = true }
        )
        draft.content = "Private reflection"
        let saved = await draft.save(authorize: {
            state.account = BibleReaderViewModelTestSupport.makeAccount(userID: "second-user")
        })
        #expect(!saved)
        #expect(!didCreate)
        #expect(draft.isInvalidated)
        #expect(draft.content.isEmpty)
    }

    @Test
    func unidentifiedAccountsUseTheTokenToDetectReplacement() {
        let first = BibleReaderAccount(userID: nil, accessToken: "first", appKey: "tests", apiHost: "api.youversion.com")
        let second = BibleReaderAccount(userID: nil, accessToken: "second", appKey: "tests", apiHost: "api.youversion.com")
        #expect(first != second)
    }

    private func makeViewModel(state: NoteAccountState) -> BibleReaderViewModel {
        BibleReaderViewModelTestSupport.makeViewModel(
            readIsSignedIn: { state.account != nil }, signOut: { state.account = nil }, readAccount: { state.account }
        )
    }

    private func savedNote() throws -> YouVersionNote {
        try JSONDecoder().decode(YouVersionNote.self, from: Data(#"{"id":"private","content":"Private saved text","status":"private"}"#.utf8))
    }
}

@MainActor
private final class NoteAccountState {
    var account: BibleReaderAccount? = BibleReaderViewModelTestSupport.makeAccount(userID: "first-user")
}
