import Foundation
import Observation
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// A new or existing note being edited in the reader.
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
    private let hasValidReferences: Bool
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
    private(set) var editingNote: YouVersionNote?
    private var requestID = UUID()
    private var operationTask: Task<Bool, Never>?
    private let currentAccount: @MainActor () -> BibleReaderAccount?
    private let deleteNote: @MainActor (String) async throws -> Void
    private let createNote: @MainActor (YouVersionNoteCreateRequest) async throws -> Void
    private let updateNote: @MainActor (String, YouVersionNoteUpdate) async throws -> Void

    /// Captures the exact selection, including nonconsecutive verses within one chapter.
    init(
        references: [BibleReference],
        referenceTitle: String,
        savedNotes: [YouVersionNote] = [],
        account: BibleReaderAccount? = BibleReaderAccount.current,
        currentAccount: @escaping @MainActor () -> BibleReaderAccount? = { BibleReaderAccount.current },
        createNote: @escaping @MainActor (YouVersionNoteCreateRequest) async throws -> Void = BibleReaderNoteDraft.defaultCreateNote,
        deleteNote: @escaping @MainActor (String) async throws -> Void = BibleReaderNoteDraft.defaultDeleteNote,
        updateNote: @escaping @MainActor (String, YouVersionNoteUpdate) async throws -> Void = BibleReaderNoteDraft.defaultUpdateNote
    ) {
        selection = Set(references)
        self.references = BibleReference.referencesByMerging(references: references.sorted())
        self.referenceTitle = referenceTitle
        self.savedNotes = savedNotes
        self.account = account
        self.currentAccount = currentAccount
        self.hasValidReferences = normalizedNoteReferences(self.references) != nil
        self.createNote = createNote
        self.deleteNote = deleteNote
        self.updateNote = updateNote
    }

    var isBusy: Bool { isSaving || isDeleting }
    var hasTextChanges: Bool { content != (editingNote?.content ?? "") }
    private var hasVisibilityChanges: Bool { isPublic != (editingNote?.status == .public) }
    private var hasColorChanges: Bool { colorHex != editingNote?.color }
    var hasChanges: Bool { hasTextChanges || hasVisibilityChanges || hasColorChanges }
    var canSave: Bool {
        guard !isBusy && !isInvalidated && account == currentAccount() else {
            return false
        }
        if editingNote != nil {
            return hasChanges && (!hasTextChanges || !content.isEmpty)
        }
        return hasValidReferences
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
        editingNote = nil
        showingSaveError = false
        showingDiscardConfirmation = false
    }

    /// Opens a saved note in the composer without changing its attachment or other metadata.
    func edit(noteID: String) {
        guard !isBusy && validateAccount() && editingNote?.id != noteID,
              let note = savedNotes.first(where: { $0.id == noteID }) else {
            return
        }
        editingNote = note
        content = note.content
        isPublic = note.status == .public
        colorHex = note.color
    }

    /// Reselecting the saved swatch restores its original encoding and opacity.
    func selectColor(hex: String) {
        if let savedHex = editingNote?.color, let rgb = Color.rgbValue(fromHex: hex), rgb == Color.rgbValue(fromHex: savedHex) {
            colorHex = savedHex
        } else {
            colorHex = hex
        }
    }

    private static func defaultCreateNote(_ request: YouVersionNoteCreateRequest) async throws {
        guard let accessToken = YouVersionPlatformConfiguration.accessToken else {
            throw YouVersionAPIError.missingAuthentication
        }
        _ = try await YouVersionAPI.Notes.createNote(request, accessToken: accessToken)
    }

    private static func defaultUpdateNote(_ id: String, _ update: YouVersionNoteUpdate) async throws {
        guard let accessToken = YouVersionPlatformConfiguration.accessToken else {
            throw YouVersionAPIError.missingAuthentication
        }
        _ = try await YouVersionAPI.Notes.updateNote(id: id, update: update, accessToken: accessToken)
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
        let isDeleted = await perform(authorize: authorize) { try await self.deleteNote(note.id) }
        guard isDeleted && validateAccount() else {
            return false
        }
        if editingNote?.id == note.id {
            if !hasChanges {
                content = ""
                isPublic = false
                colorHex = nil
            }
            editingNote = nil
        }
        savedNotes.removeAll { $0.id == note.id }
        NotificationCenter.default.post(name: .youVersionNotesChanged, object: nil)
        return true
    }

    /// Creates a new note or patches an existing one. A failure preserves the draft for retry.
    func save(authorize: @escaping @MainActor () async throws -> Void = {}) async -> Bool {
        guard validateAccount() && canSave else {
            return false
        }
        isSaving = true
        defer { isSaving = false }
        let status: YouVersionNote.Status = isPublic ? .public : .private
        let isSaved: Bool
        if let editingNote {
            let update = YouVersionNoteUpdate(
                content: hasTextChanges ? content : nil,
                color: hasColorChanges ? (colorHex.map { .value($0) } ?? .clear) : nil,
                status: hasVisibilityChanges ? status : nil
            )
            isSaved = await perform(authorize: authorize) { try await self.updateNote(editingNote.id, update) }
        } else {
            let request = YouVersionNoteCreateRequest(
                content: content, status: status, requestID: requestID, color: colorHex, references: references
            )
            isSaved = await perform(authorize: authorize) { try await self.createNote(request) }
        }
        guard isSaved && validateAccount() else {
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
