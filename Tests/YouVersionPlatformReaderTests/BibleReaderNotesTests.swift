import Foundation
import SwiftUI
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
struct BibleReaderNotesTests {
    private let first = BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16)
    private let second = BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 17)

    @Test
    func capturesAndMergesSelectionBeforeOpeningComposer() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == "highlights" }
        )
        viewModel.selectedVerses = [first, second]
        viewModel.showingVerseActionsDrawer = true
        viewModel.startNote()
        let draft = viewModel.noteDraft
        #expect(draft?.referenceTitle.isEmpty == false)
        #expect(!viewModel.showingVerseActionsDrawer)
        #expect(draft?.passage == YouVersionNote.Passage(bibleID: 3034, passageID: "JHN.3.16-17"))
        viewModel.selectedVerses = []
        #expect(draft?.references.count == 1)
        #expect(draft?.passage?.passageID == "JHN.3.16-17")
    }

    @Test
    func emptySelectionDoesNotOpenComposer() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == "highlights" }
        )
        viewModel.startNote()
        #expect(viewModel.noteDraft == nil)
    }

    @Test
    func separatedVersesSaveWithoutIncludingTheGap() async throws {
        let third = BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 18)
        var created: YouVersionNoteCreateRequest?
        let draft = BibleReaderNoteDraft(references: [first, third], referenceTitle: "John 3:16, 18") { created = $0 }
        draft.content = "Reflection"
        #expect(draft.references.count == 2)
        #expect(draft.passage?.passageID == "JHN.3.16+JHN.3.18")
        #expect(draft.canSave)
        #expect(await draft.save())
        let passage = try #require(created?.passage)
        #expect(passage.references == [first, third])
    }

    @Test(arguments: ["", " \n\t "])
    func blankContentCannotCreateNote(content: String) async {
        var didCreate = false
        let draft = BibleReaderNoteDraft(references: [first], referenceTitle: "John 3:16") { _ in didCreate = true }
        draft.content = content
        #expect(!draft.canSave)
        #expect(await draft.save() == false)
        #expect(!didCreate)
    }

    @Test
    func privacyAndColorEditsEnableSaveWithoutInventingText() {
        let draft = BibleReaderNoteDraft(references: [first], referenceTitle: "John 3:16")
        #expect(!draft.hasChanges)
        #expect(!draft.canSave)
        draft.isPublic = true
        #expect(draft.hasChanges)
        #expect(!draft.hasTextChanges)
        #expect(draft.canSave)
        draft.isPublic = false
        #expect(!draft.hasChanges)
        #expect(!draft.canSave)
        draft.colorHex = "ffec5b"
        #expect(draft.hasChanges)
        #expect(draft.canSave)
        draft.colorHex = nil
        #expect(!draft.canSave)
        draft.content = "Reflection"
        draft.isPublic = true
        #expect(draft.canSave)
        draft.isPublic = false
        #expect(draft.canSave)
    }

    @Test
    func savesExactContentVisibilityColorAndCapturedPassage() async throws {
        var captured: YouVersionNoteCreateRequest?
        let draft = BibleReaderNoteDraft(references: [first, second], referenceTitle: "John 3:16-17") { captured = $0 }
        draft.content = "My reflection\nAnother line"
        draft.isPublic = true
        draft.colorHex = "ffec5b"
        #expect(await draft.save())
        let request = try #require(captured)
        #expect(request.content == draft.content)
        #expect(request.status == .public)
        #expect(request.color == "ffec5b")
        #expect(request.passage == YouVersionNote.Passage(bibleID: 3034, passageID: "JHN.3.16-17"))
        #expect(!draft.isSaving)
    }

    @Test
    func failedCreateRetainsDraftAndIdempotencyUntilPayloadChanges() async throws {
        var requests: [YouVersionNoteCreateRequest] = []
        let draft = BibleReaderNoteDraft(references: [first], referenceTitle: "John 3:16") { request in
            requests.append(request)
            throw URLError(.timedOut)
        }
        draft.content = "Keep this text"
        #expect(await draft.save() == false)
        #expect(draft.showingSaveError)
        #expect(draft.content == "Keep this text")
        #expect(!draft.isSaving)
        #expect(await draft.save() == false)
        #expect(requests[0].requestID == requests[1].requestID)
        #expect(requests[0].status == .private)
        draft.isPublic = true
        #expect(await draft.save() == false)
        #expect(requests[2].requestID != requests[1].requestID)
        #expect(requests[2].status == .public)
    }

    @Test
    func authorizationFailureDoesNotSendCreateOrLoseText() async {
        var didCreate = false
        let draft = BibleReaderNoteDraft(references: [first], referenceTitle: "John 3:16") { _ in didCreate = true }
        draft.content = "Keep me"
        let saved = await draft.save(authorize: { throw YouVersionAPIError.notPermitted })
        #expect(!saved)
        #expect(!didCreate)
        #expect(draft.content == "Keep me")
        #expect(draft.showingSaveError)
        #expect(!draft.isSaving)
    }

    @Test
    func savingBlocksDuplicateSubmitAndDismissal() async {
        var continuation: CheckedContinuation<Void, Never>?
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == "highlights" }
        )
        let draft = BibleReaderNoteDraft(references: [first], referenceTitle: "John 3:16") { _ in
            await withCheckedContinuation { continuation = $0 }
        }
        draft.content = "Reflection"
        viewModel.noteDraft = draft
        let task = Task { await draft.save() }
        while continuation == nil { await Task.yield() }
        #expect(draft.isSaving)
        #expect(await draft.save() == false)
        viewModel.requestDismissNote()
        viewModel.discardNote()
        #expect(viewModel.noteDraft === draft)
        #expect(!draft.showingDiscardConfirmation)
        continuation?.resume()
        #expect(await task.value)
    }

    @Test
    func dismissalConfirmsOnlyChangedTextAndDiscardClearsSelection() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == "highlights" }
        )
        viewModel.selectedVerses = [first]
        viewModel.startNote()
        viewModel.noteDraft?.content = "Unsaved"
        viewModel.requestDismissNote()
        #expect(viewModel.noteDraft?.showingDiscardConfirmation == true)
        #expect(viewModel.selectedVerses == [first])
        viewModel.noteDraft?.showingDiscardConfirmation = false
        #expect(viewModel.noteDraft?.content == "Unsaved")
        viewModel.discardNote()
        #expect(viewModel.noteDraft == nil)
        #expect(viewModel.selectedVerses.isEmpty)
        viewModel.selectedVerses = [first]
        viewModel.startNote()
        viewModel.noteDraft?.isPublic = true
        viewModel.requestDismissNote()
        #expect(viewModel.noteDraft == nil)
    }

    @Test
    func completedSaveCannotCloseANewerDraft() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == "highlights" }
        )
        let old = BibleReaderNoteDraft(references: [first], referenceTitle: "John 3:16")
        let current = BibleReaderNoteDraft(references: [second], referenceTitle: "John 3:17")
        viewModel.noteDraft = current
        viewModel.finishNote(old)
        #expect(viewModel.noteDraft === current)
        viewModel.finishNote(current)
        #expect(viewModel.noteDraft == nil)
    }

    @Test
    func customActionReceivesSelectionAndPresetsHaveStableIDs() {
        var selected: [BibleReference] = []
        let action = BibleReaderVerseAction(id: "custom", title: "Custom", systemImage: "star") { selected = $0 }
        action.action?([first])
        #expect(action.image == Image(systemName: "star"))
        #expect(selected == [first])
        #expect([BibleReaderVerseAction.highlight, .save, .copy, .share].map(\.id) == ["highlight", "save", "copy", "share"])
    }

    @Test
    func customActionRetainsProvidedImageAndCallback() {
        let image = Image("custom-action")
        var selected: [BibleReference] = []
        let action = BibleReaderVerseAction(id: "custom-image", title: "Custom", image: image) { selected = $0 }
        #expect(action.image == image)
        action.action?([first, second])
        #expect(selected == [first, second])
    }

}
