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
    var showingSaveError = false
    var showingDiscardConfirmation = false
    private var requestID = UUID()
    private let createNote: @MainActor (YouVersionNoteCreateRequest) async throws -> Void

    /// Captures the exact selection, including nonconsecutive verses within one chapter.
    init(
        references: [BibleReference],
        referenceTitle: String,
        createNote: @escaping @MainActor (YouVersionNoteCreateRequest) async throws -> Void = { request in
            _ = try await YouVersionAPI.Notes.createNote(request)
        }
    ) {
        selection = Set(references)
        self.references = BibleReference.referencesByMerging(references: references.sorted())
        self.referenceTitle = referenceTitle
        self.passage = YouVersionNote.Passage(references: self.references)
        self.createNote = createNote
    }

    var hasTextChanges: Bool { !content.isEmpty }
    var hasChanges: Bool { hasTextChanges || isPublic || colorHex != nil }
    var canSave: Bool {
        let hasEdits = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPublic || colorHex != nil
        return hasEdits && passage != nil && !isSaving
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
