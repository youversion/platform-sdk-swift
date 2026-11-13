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
    private(set) var account: BibleReaderAccount?
    private(set) var isInvalidated = false
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
    private var hasCopiedText = false
    private var requestID = UUID()
    private var operationTask: Task<Bool, Never>?
    private let currentAccount: @MainActor () -> BibleReaderAccount?
    private let deleteNote: @MainActor (String) async throws -> Void
    private let createNote: @MainActor (YouVersionNoteCreateRequest) async throws -> Void

    /// Captures the exact selection, including nonconsecutive verses within one chapter.
    init(
        references: [BibleReference],
        referenceTitle: String,
        savedNotes: [YouVersionNote] = [],
        account: BibleReaderAccount? = BibleReaderAccount.current,
        currentAccount: @escaping @MainActor () -> BibleReaderAccount? = { BibleReaderAccount.current },
        createNote: @escaping @MainActor (YouVersionNoteCreateRequest) async throws -> Void = BibleReaderNoteDraft.defaultCreateNote,
        deleteNote: @escaping @MainActor (String) async throws -> Void = BibleReaderNoteDraft.defaultDeleteNote
    ) {
        selection = Set(references)
        self.references = BibleReference.referencesByMerging(references: references.sorted())
        self.referenceTitle = referenceTitle
        self.savedNotes = savedNotes
        self.account = account
        self.currentAccount = currentAccount
        self.passage = YouVersionNote.Passage(references: self.references)
        self.createNote = createNote
        self.deleteNote = deleteNote
    }

    var isBusy: Bool { isSaving || isDeleting }
    var hasTextChanges: Bool { content != originalContent }
    var hasChanges: Bool { hasTextChanges || hasMetadataChanges }
    private var hasMetadataChanges: Bool { isPublic != originalIsPublic || colorHex != originalColorHex }
    var canSave: Bool {
        (!hasCopiedText || hasChanges) && passage != nil && !isBusy && !isInvalidated && account == currentAccount()
    }

    /// Binds a signed-out selection to the account that completed its authorization.
    func bind(to account: BibleReaderAccount) -> Bool {
        guard !isInvalidated && (self.account == nil || self.account == account) else {
            invalidate()
            return false
        }
        self.account = account
        return true
    }

    /// Clears account-owned content and cancels any pending authorization or mutation.
    func invalidate() {
        isInvalidated = true
        operationTask?.cancel()
        savedNotes = []
        content = ""
        isPublic = false
        colorHex = nil
        originalContent = ""
        originalIsPublic = false
        originalColorHex = nil
        showingSaveError = false
        showingDiscardConfirmation = false
    }

    /// Copies saved text as the starting point for a new note; unchanged copies cannot be saved.
    func copyText(from note: YouVersionNote) {
        guard !isInvalidated && !isBusy else {
            return
        }
        content = note.content
        originalContent = note.content
        originalIsPublic = isPublic
        originalColorHex = colorHex
        hasCopiedText = true
    }

    private static func defaultCreateNote(_ request: YouVersionNoteCreateRequest) async throws {
        guard let accessToken = YouVersionPlatformConfiguration.accessToken else {
            throw YouVersionAPIError.missingAuthentication
        }
        _ = try await YouVersionAPI.Notes.createNote(request, accessToken: accessToken)
    }

    private static func defaultDeleteNote(_ id: String) async throws {
        guard let accessToken = YouVersionPlatformConfiguration.accessToken else {
            throw YouVersionAPIError.missingAuthentication
        }
        _ = try await YouVersionAPI.Notes.deleteNote(id: id, accessToken: accessToken)
    }

    /// Removes a saved note only after the server confirms deletion, preserving the composer on failure.
    func delete(_ note: YouVersionNote, authorize: @escaping @MainActor () async throws -> Void = {}) async -> Bool {
        guard !isBusy && validateAccount() && savedNotes.contains(where: { $0.id == note.id }) else {
            return false
        }
        isDeleting = true
        defer { isDeleting = false }
        let deleted = await perform(authorize: authorize) { try await self.deleteNote(note.id) }
        guard deleted && validateAccount() else {
            return false
        }
        savedNotes.removeAll { $0.id == note.id }
        NotificationCenter.default.post(name: .youVersionNotesChanged, object: nil)
        return true
    }

    /// Saves the note. Failure preserves all fields and the request UUID so retrying cannot create a duplicate.
    func save(authorize: @escaping @MainActor () async throws -> Void = {}) async -> Bool {
        guard validateAccount() && canSave else {
            return false
        }
        isSaving = true
        defer { isSaving = false }
        let request = YouVersionNoteCreateRequest(
            content: content, status: isPublic ? .public : .private,
            requestID: requestID, color: colorHex, passage: passage
        )
        let saved = await perform(authorize: authorize) { try await self.createNote(request) }
        guard saved && validateAccount() else {
            return false
        }
        NotificationCenter.default.post(name: .youVersionNotesChanged, object: nil)
        return true
    }

    // Validation also invalidates and cancels account-owned state on failure.
    // swiftlint:disable:next var_over_func
    private func validateAccount() -> Bool {
        guard !isInvalidated && account == currentAccount() else {
            invalidate()
            return false
        }
        return true
    }

    private func perform(
        authorize: @escaping @MainActor () async throws -> Void,
        operation: @escaping @MainActor () async throws -> Void
    ) async -> Bool {
        let task = Task {
            do {
                try Task.checkCancellation()
                try await authorize()
                try Task.checkCancellation()
                guard validateAccount() else {
                    return false
                }
                try await operation()
                try Task.checkCancellation()
                return validateAccount()
            } catch {
                if validateAccount() && !Task.isCancelled {
                    showingSaveError = true
                }
                return false
            }
        }
        operationTask = task
        defer { operationTask = nil }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
