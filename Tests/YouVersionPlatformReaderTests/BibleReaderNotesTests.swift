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
            isSignedIn: true, hasPermission: { $0 == YouVersionAPI.Users.writeNotesPermission }
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
    func savingConsecutiveVersesShowsTheSameNoteOnBothIndicators() async throws {
        var savedNotes: [YouVersionNote] = []
        let model = BibleNoteIndicatorsModel(hasAccess: { true }) { _, _ in
            let encoded = try JSONEncoder().encode(savedNotes)
            let data = Data("{\"data\":".utf8) + encoded + Data("}".utf8)
            return try JSONDecoder().decode(YouVersionNoteCollection.self, from: data)
        }
        let draft = BibleReaderNoteDraft(references: [first, second], referenceTitle: "John 3:16–17") { request in
            let data = try JSONEncoder().encode(request)
            var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            json["id"] = "consecutive-note"
            savedNotes = [try JSONDecoder().decode(YouVersionNote.self, from: JSONSerialization.data(withJSONObject: json))]
        }
        await model.load(first.chapterReference)
        #expect(model.notes(for: first).isEmpty)
        #expect(model.notes(for: second).isEmpty)
        draft.content = "Reflection on both verses"
        #expect(await draft.save())
        await model.load(first.chapterReference)
        #expect(model.notes(for: first).map(\.id) == ["consecutive-note"])
        #expect(model.notes(for: second).map(\.id) == ["consecutive-note"])
        let neighbor = BibleReference(versionId: first.versionId, bookId: first.bookId, chapter: first.chapter, verse: 18)
        #expect(model.notes(for: neighbor).isEmpty)
    }

    @Test
    func emptySelectionDoesNotOpenComposer() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == YouVersionAPI.Users.writeNotesPermission }
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
        #expect(!draft.canSave)
        draft.isPublic = true
        #expect(!draft.hasTextChanges)
        #expect(draft.canSave)
        draft.isPublic = false
        #expect(!draft.canSave)
        draft.colorHex = "ffec5b"
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
            isSignedIn: true, hasPermission: { $0 == YouVersionAPI.Users.writeNotesPermission }
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
    func dismissalConfirmsAllChangedFieldsAndDiscardClearsSelection() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == YouVersionAPI.Users.writeNotesPermission }
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
        #expect(viewModel.noteDraft?.showingDiscardConfirmation == true)
        viewModel.discardNote()
        viewModel.selectedVerses = [first]
        viewModel.startNote()
        viewModel.noteDraft?.colorHex = "ffec5b"
        viewModel.requestDismissNote()
        #expect(viewModel.noteDraft?.showingDiscardConfirmation == true)
        viewModel.noteDraft?.colorHex = nil
        viewModel.noteDraft?.showingDiscardConfirmation = false
        viewModel.requestDismissNote()
        #expect(viewModel.noteDraft == nil)
    }

    @Test
    func indicatorOpensBlankComposerForTappedVerseWithSavedNotes() throws {
        let note = try JSONDecoder().decode(YouVersionNote.self, from: Data("""
        {"id":"original","content":"Original text","status":"public","color":"ffec5b",
         "passage":{"bible_id":3034,"passage_id":"JHN.3.16-17"}}
        """.utf8))
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(isSignedIn: true, hasPermission: { _ in false })
        viewModel.showingVerseActionsDrawer = true
        viewModel.showNotes(for: second, notes: [note])
        let draft = try #require(viewModel.noteDraft)
        #expect(!viewModel.showingVerseActionsDrawer)
        #expect(draft.savedNotes == [note])
        #expect(draft.references == [second])
        #expect(draft.content.isEmpty)
        #expect(!draft.isPublic)
        #expect(draft.colorHex == nil)
        #expect(!draft.canSave)
    }

    @Test
    func savingCopiedTextCreatesNewNoteWithoutChangingOriginal() async throws {
        let note = try JSONDecoder().decode(YouVersionNote.self, from: Data("""
        {"id":"original","content":"Original text","status":"public","color":"ffec5b"}
        """.utf8))
        var created: YouVersionNoteCreateRequest?
        let draft = BibleReaderNoteDraft(references: [first], referenceTitle: "John 3:16", savedNotes: [note]) { created = $0 }
        draft.copyText(from: note)
        #expect(!draft.canSave)
        draft.content += " with a new reflection"
        #expect(await draft.save())
        #expect(created?.content == "Original text with a new reflection")
        #expect(created?.status == .private)
        #expect(created?.color == nil)
        #expect(draft.savedNotes == [note])
        #expect(note.content == "Original text")
    }

    @Test
    func copiedTextRequiresAnEditAndRevertingItDisablesSave() throws {
        let note = try JSONDecoder().decode(YouVersionNote.self, from: Data("""
        {"id":"original","content":"Saved reflection","status":"private"}
        """.utf8))
        let draft = BibleReaderNoteDraft(references: [first], referenceTitle: "John 3:16")
        draft.copyText(from: note)
        #expect(!draft.canSave)
        #expect(!draft.hasChanges)
        draft.content += " edited"
        #expect(draft.canSave)
        draft.content = note.content
        #expect(!draft.canSave)
        draft.isPublic = true
        #expect(draft.canSave)
        draft.isPublic = false
        #expect(!draft.canSave)
        draft.colorHex = "ffec5b"
        #expect(draft.canSave)
        draft.colorHex = nil
        #expect(!draft.canSave)
        #expect(!draft.hasChanges)
    }

    @Test
    func copyingStartsBaselineFromCurrentVisibilityAndColor() throws {
        let note = try JSONDecoder().decode(YouVersionNote.self, from: Data("""
        {"id":"original","content":"Saved reflection","status":"private"}
        """.utf8))
        let draft = BibleReaderNoteDraft(references: [first], referenceTitle: "John 3:16")
        draft.isPublic = true
        draft.colorHex = "ffec5b"
        draft.copyText(from: note)
        #expect(draft.isPublic)
        #expect(draft.colorHex == "ffec5b")
        #expect(!draft.canSave)
        #expect(!draft.hasChanges)
        draft.isPublic = false
        #expect(draft.canSave)
        draft.isPublic = true
        #expect(!draft.canSave)
        draft.colorHex = nil
        #expect(draft.canSave)
        draft.colorHex = "ffec5b"
        #expect(!draft.canSave)
    }

    @Test
    func deletionRemovesOnlyTheConfirmedNoteAndKeepsComposerText() async throws {
        let data = Data("""
        [{"id":"first","content":"Saved text","status":"private"},
         {"id":"second","content":"Another note","status":"public"}]
        """.utf8)
        let notes = try JSONDecoder().decode([YouVersionNote].self, from: data)
        var deletedIDs: [String] = []
        let draft = BibleReaderNoteDraft(
            references: [first], referenceTitle: "John 3:16", savedNotes: notes,
            deleteNote: { deletedIDs.append($0) }
        )
        draft.content = "Unsaved reflection"
        draft.isPublic = true
        #expect(await draft.delete(notes[0]))
        #expect(deletedIDs == ["first"])
        #expect(draft.savedNotes == [notes[1]])
        #expect(draft.content == "Unsaved reflection")
        #expect(draft.isPublic)
        #expect(!draft.isBusy)
        #expect(await draft.delete(notes[0]) == false)
        #expect(deletedIDs == ["first"])
    }

    @Test(arguments: [true, false])
    func failedDeletionRetainsSavedNoteAndDraft(failsAuthorization: Bool) async throws {
        let note = try JSONDecoder().decode(YouVersionNote.self, from: Data("""
        {"id":"original","content":"Saved text","status":"private"}
        """.utf8))
        var didDelete = false
        let draft = BibleReaderNoteDraft(
            references: [first], referenceTitle: "John 3:16", savedNotes: [note],
            deleteNote: { _ in
                didDelete = true
                throw URLError(.notConnectedToInternet)
            }
        )
        draft.content = "Keep this draft"
        let deleted = await draft.delete(note, authorize: {
            if failsAuthorization { throw YouVersionAPIError.notPermitted }
        })
        #expect(!deleted)
        #expect(didDelete == !failsAuthorization)
        #expect(draft.savedNotes == [note])
        #expect(draft.content == "Keep this draft")
        #expect(draft.showingSaveError)
        #expect(!draft.isBusy)
    }

    @Test
    func deletionBlocksConcurrentSaveDeleteAndDismissal() async throws {
        let note = try JSONDecoder().decode(YouVersionNote.self, from: Data("""
        {"id":"original","content":"Saved text","status":"private"}
        """.utf8))
        var continuation: CheckedContinuation<Void, Never>?
        let draft = BibleReaderNoteDraft(
            references: [first], referenceTitle: "John 3:16", savedNotes: [note],
            deleteNote: { _ in await withCheckedContinuation { continuation = $0 } }
        )
        draft.content = "Keep me"
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(isSignedIn: true)
        viewModel.noteDraft = draft
        let task = Task { await draft.delete(note) }
        while continuation == nil { await Task.yield() }
        #expect(draft.isDeleting)
        #expect(!draft.canSave)
        #expect(await draft.save() == false)
        #expect(await draft.delete(note) == false)
        viewModel.requestDismissNote()
        viewModel.discardNote()
        #expect(viewModel.noteDraft === draft)
        continuation?.resume()
        #expect(await task.value)
    }

    @Test
    func completedSaveCannotCloseANewerDraft() {
        let viewModel = BibleReaderViewModelTestSupport.makeViewModel(
            isSignedIn: true, hasPermission: { $0 == YouVersionAPI.Users.writeNotesPermission }
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
