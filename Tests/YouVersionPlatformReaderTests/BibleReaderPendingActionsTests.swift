import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
struct BibleReaderPendingActionsTests {
    private let first = BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16)
    private let second = BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 17)

    @Test(arguments: ["declined", "promptCancelled", "failed"])
    func noteAuthorizationRetainsDraftAndSelectionUntilExplicitRetry(outcome: String) throws {
        let authentication = MockBibleReaderAuthenticationState(isSignedIn: false)
        let model = BibleReaderViewModelTestSupport.makeViewModel(readIsSignedIn: { authentication.isSignedIn })
        model.selectedVerses = [first, second]
        model.startNote()
        let draft = try #require(model.pendingNoteDraft)
        draft.content = "Keep this reflection"
        draft.isPublic = true
        draft.colorHex = "ffec5b"
        model.selectedVerses = []
        switch outcome {
        case "declined":
            authentication.isSignedIn = true
            model.completeSignInFlow(with: ["read_notes"])
        case "promptCancelled":
            model.cancelSignInPrompt()
        default:
            model.cancelSignInFlow()
        }
        #expect(model.pendingNoteDraft === draft)
        #expect(model.noteDraft == nil)
        #expect(model.selectedVerses == [first, second])
        #expect(model.showingVerseActionsDrawer)
        authentication.isSignedIn = true
        model.completeSignInFlow(with: ["read_notes", "write_notes"])
        #expect(model.noteDraft == nil)
        #expect(model.pendingNoteDraft === draft)
        model.startNote()
        #expect(model.pendingNoteDraft === draft)
        model.completeSignInFlow(with: ["write_notes"])
        #expect(model.noteDraft === draft)
        #expect(model.pendingNoteDraft == nil)
        #expect(draft.content == "Keep this reflection")
        #expect(draft.isPublic)
        #expect(draft.colorHex == "ffec5b")
    }

    @Test(arguments: [true, false])
    func highlightConsentRetainsSelectionUntilTheUserChoosesAColorAgain(cancelPrompt: Bool) {
        let repository = MockBibleHighlightsRepository()
        let model = BibleReaderViewModelTestSupport.makeViewModel(highlightsRepository: repository, isSignedIn: true)
        model.selectedVerses = [first, second]
        model.addHighlightOrStartPermissionFlow(references: [first, second], color: "DDAAFF")
        model.selectedVerses = []
        if cancelPrompt {
            model.cancelDataExchangePrompt()
        } else {
            model.confirmDataExchangePrompt()
            model.completeDataExchangeFlow(with: [])
        }
        #expect(repository.queuedOperations.isEmpty)
        #expect(model.selectedVerses == [first, second])
        #expect(model.showingVerseActionsDrawer)
        model.completeDataExchangeFlow(with: ["highlights"])
        #expect(repository.queuedOperations.isEmpty)
        model.addHighlightOrStartPermissionFlow(references: model.selectedVerses, color: "DDAAFF")
        model.confirmDataExchangePrompt()
        model.completeDataExchangeFlow(with: ["highlights"])
        #expect(repository.queuedOperations.count == 1)
        #expect(Set(repository.queuedOperations.first?.references ?? []) == [first, second])
        #expect(repository.queuedOperations.first?.color == "DDAAFF")
        #expect(model.selectedVerses.isEmpty)
        model.completeDataExchangeFlow(with: ["highlights"])
        #expect(repository.queuedOperations.count == 1)
    }

    @Test
    func failedHighlightSignInRetainsActionButUnrelatedLoginDoesNotApplyIt() {
        let authentication = MockBibleReaderAuthenticationState(isSignedIn: false)
        let repository = MockBibleHighlightsRepository()
        let model = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: repository, readIsSignedIn: { authentication.isSignedIn }, hasPermission: { $0 == "highlights" }
        )
        model.selectedVerses = [first]
        model.addHighlightOrStartPermissionFlow(references: [first], color: "DDAAFF")
        model.cancelSignInFlow()
        authentication.isSignedIn = true
        model.completeSignInFlow(with: ["highlights"])
        #expect(repository.queuedOperations.isEmpty)
        #expect(model.selectedVerses == [first])
        model.addHighlightOrStartPermissionFlow(references: model.selectedVerses, color: "DDAAFF")
        #expect(repository.queuedOperations.first?.color == "DDAAFF")
    }

    @Test(arguments: [true, false])
    func partialOAuthGrantPreservesTheOtherPendingAction(grantNotes: Bool) throws {
        let authentication = MockBibleReaderAuthenticationState(isSignedIn: false)
        let repository = MockBibleHighlightsRepository()
        let model = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: repository, readIsSignedIn: { authentication.isSignedIn },
            hasPermission: { $0 == "highlights" }
        )
        model.selectedVerses = [first]
        model.addHighlightOrStartPermissionFlow(references: [first], color: "DDAAFF")
        model.selectedVerses = [second]
        model.startNote()
        let draft = try #require(model.pendingNoteDraft)
        draft.content = "Keep the other pending action"
        authentication.isSignedIn = true
        model.completeSignInFlow(with: grantNotes ? ["write_notes"] : ["highlights"])
        if grantNotes {
            #expect(model.noteDraft === draft)
            #expect(repository.queuedOperations.isEmpty)
            model.addHighlightOrStartPermissionFlow(references: model.selectedVerses, color: "DDAAFF")
            #expect(repository.queuedOperations.count == 1)
        } else {
            #expect(model.noteDraft == nil)
            #expect(model.pendingNoteDraft === draft)
            #expect(model.selectedVerses == [second])
            model.startNote()
            model.completeSignInFlow(with: ["write_notes"])
        }
        #expect(model.noteDraft === draft)
        #expect(draft.content == "Keep the other pending action")
        #expect(repository.queuedOperations.count == 1)
        #expect(repository.queuedOperations.first?.references == [first])
        #expect(repository.queuedOperations.first?.color == "DDAAFF")
    }

    @Test
    func unsuccessfulSignedInStatePausesHighlightEvenWhenCallbackReportsPermission() {
        let authentication = MockBibleReaderAuthenticationState(isSignedIn: false)
        let repository = MockBibleHighlightsRepository()
        let model = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: repository, readIsSignedIn: { authentication.isSignedIn }, hasPermission: { $0 == "highlights" }
        )
        model.selectedVerses = [first]
        model.addHighlightOrStartPermissionFlow(references: [first], color: "DDAAFF")
        model.completeSignInFlow(with: ["highlights"])
        authentication.isSignedIn = true
        model.completeSignInFlow(with: ["highlights"])
        #expect(repository.queuedOperations.isEmpty)
        #expect(model.selectedVerses == [first])
    }

    @Test
    func grantingBothPermissionsResumesBothCapturedActionsExactlyOnce() throws {
        let authentication = MockBibleReaderAuthenticationState(isSignedIn: false)
        let repository = MockBibleHighlightsRepository()
        let model = BibleReaderViewModelTestSupport.makeViewModel(
            highlightsRepository: repository, readIsSignedIn: { authentication.isSignedIn }, hasPermission: { $0 == "highlights" }
        )
        model.selectedVerses = [first]
        model.addHighlightOrStartPermissionFlow(references: [first], color: "DDAAFF")
        model.selectedVerses = [second]
        model.startNote()
        let draft = try #require(model.pendingNoteDraft)
        authentication.isSignedIn = true
        model.completeSignInFlow(with: ["highlights", "write_notes"])
        model.completeSignInFlow(with: ["highlights", "write_notes"])
        #expect(model.noteDraft === draft)
        #expect(draft.selection == [second])
        #expect(repository.queuedOperations.count == 1)
        #expect(repository.queuedOperations.first?.references == [first])
    }

    @Test(arguments: [URLError.Code.cancelled, .notConnectedToInternet, .userAuthenticationRequired])
    func noteSaveAuthorizationFailuresKeepAllEnteredData(code: URLError.Code) async {
        let draft = BibleReaderNoteDraft(references: [first, second], referenceTitle: "John 3:16–17") { _ in
            Issue.record("No create request should be sent after failed authorization")
        }
        draft.content = "Do not lose this text"
        draft.isPublic = true
        draft.colorHex = "ffec5b"
        #expect(await draft.save(authorize: { throw URLError(code) }) == false)
        #expect(draft.content == "Do not lose this text")
        #expect(draft.isPublic)
        #expect(draft.colorHex == "ffec5b")
        #expect(draft.selection == [first, second])
        #expect(!draft.isSaving)
        #expect(draft.canSave)
    }
}
