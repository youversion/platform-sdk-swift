import Foundation
import Observation
import YouVersionPlatformCore

/// One create attempt, retaining the selection and idempotency ID across network retries.
@MainActor
@Observable
final class BibleReaderNoteDraft: Identifiable {
    let id = UUID()
    let references: [BibleReference]
    let selection: Set<BibleReference>
    let referenceTitle: String
    private(set) var savedNotes: [YouVersionNote]
    let passage: YouVersionNote.Passage?
    var content = "" {
        didSet { if content != oldValue { requestID = UUID() } }
    }
    var isPublic = false {
        didSet { if isPublic != oldValue { requestID = UUID() } }
    }
    var colorHex: String? {
        didSet { if colorHex != oldValue { requestID = UUID() } }
    }
    private(set) var isSaving = false
    private(set) var isDeleting = false
    var showingSaveError = false
    var showingDiscardConfirmation = false
    private var originalContent = ""
    private var originalIsPublic = false
    private var originalColorHex: String?
    private var requestID = UUID()
    private let deleteNote: @MainActor (String) async throws -> Void
    private let createNote: @MainActor (YouVersionNoteCreateRequest) async throws -> Void

    /// Captures the exact selection, including nonconsecutive verses within one chapter.
    init(
        references: [BibleReference],
        referenceTitle: String,
        savedNotes: [YouVersionNote] = [],
        createNote: @escaping @MainActor (YouVersionNoteCreateRequest) async throws -> Void = { request in
            _ = try await YouVersionAPI.Notes.createNote(request)
        },
        deleteNote: @escaping @MainActor (String) async throws -> Void = BibleReaderNoteDraft.defaultDeleteNote
    ) {
        selection = Set(references)
        self.references = BibleReference.referencesByMerging(references: references.sorted())
        self.referenceTitle = referenceTitle
        self.savedNotes = savedNotes
        self.passage = YouVersionNote.Passage(references: self.references)
        self.createNote = createNote
        self.deleteNote = deleteNote
    }

    var isBusy: Bool { isSaving || isDeleting }
    var hasTextChanges: Bool { content != originalContent }
    var hasChanges: Bool { hasTextChanges || hasMetadataChanges }
    private var hasMetadataChanges: Bool { isPublic != originalIsPublic || colorHex != originalColorHex }
    var canSave: Bool {
        let hasEdits = (hasTextChanges && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || hasMetadataChanges
        return hasEdits && passage != nil && !isBusy
    }

    /// Copies saved text as the starting point for a new note; unchanged copies cannot be saved.
    func copyText(from note: YouVersionNote) {
        content = note.content
        originalContent = note.content
        originalIsPublic = isPublic
        originalColorHex = colorHex
    }

    private static func defaultDeleteNote(_ id: String) async throws {
        _ = try await YouVersionAPI.Notes.deleteNote(id: id)
    }

    /// Removes a saved note only after the server confirms deletion, preserving the composer on failure.
    func delete(_ note: YouVersionNote, authorize: @MainActor () async throws -> Void = {}) async -> Bool {
        guard !isBusy && savedNotes.contains(where: { $0.id == note.id }) else {
            return false
        }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await authorize()
            try await deleteNote(note.id)
            savedNotes.removeAll { $0.id == note.id }
            NotificationCenter.default.post(name: .youVersionNotesChanged, object: nil)
            return true
        } catch {
            showingSaveError = true
            return false
        }
    }

    /// Saves the note. Failure preserves all fields and the request UUID so retrying cannot create a duplicate.
    func save(authorize: @MainActor () async throws -> Void = {}) async -> Bool {
        guard canSave else {
            return false
        }
        isSaving = true
        defer { isSaving = false }
        let request = YouVersionNoteCreateRequest(
            content: content, status: isPublic ? .public : .private,
            requestID: requestID, color: colorHex, passage: passage
        )
        do {
            try await authorize()
            try await createNote(request)
            NotificationCenter.default.post(name: .youVersionNotesChanged, object: nil)
            return true
        } catch {
            showingSaveError = true
            return false
        }
    }
}
