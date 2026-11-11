import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {
    var selectedVerseTitle: String {
        let references = BibleReference.referencesByMerging(references: Array(selectedVerses).sorted())
        let titles = references.map { version?.displayTitle(for: $0, includesVersionAbbreviation: false) ?? $0.passageId }
        return titles.joined(separator: .localized("shareableVerse.referencesSeparator"))
    }

    /// Captures the selection and opens Notes only after sign-in and the `write_notes` OAuth scope are satisfied.
    func startNote() {
        let references = BibleReference.referencesByMerging(references: Array(selectedVerses).sorted())
        guard !references.isEmpty else {
            return
        }
        guard isSignedIn || YouVersionPlatformConfiguration.isSignInEnabled else {
            return
        }
        let draft: BibleReaderNoteDraft
        if let pendingNoteDraft, pendingNoteDraft.references == references {
            draft = pendingNoteDraft
        } else {
            draft = BibleReaderNoteDraft(references: Array(selectedVerses), referenceTitle: selectedVerseTitle)
        }
        showingVerseActionsDrawer = false
        if isSignedIn && hasNotesPermission {
            pendingNoteDraft = nil
            isNoteAuthorizationPending = false
            noteDraft = draft
        } else {
            pendingNoteDraft = draft
            isNoteAuthorizationPending = true
            if isSignedIn {
                startSignInFlow = true
            } else {
                showingSignInSheet = true
            }
        }
    }

    /// Opens the captured draft when authentication granted the `write_notes` OAuth scope.
    func continuePendingNote(with grantedPermissions: [String]) {
        guard isNoteAuthorizationPending, let pendingNoteDraft else {
            return
        }
        guard isSignedIn && grantedPermissions.contains(Self.notesPermission) else {
            cancelPendingNote()
            return
        }
        self.pendingNoteDraft = nil
        isNoteAuthorizationPending = false
        showingVerseActionsDrawer = false
        noteDraft = pendingNoteDraft
    }

    /// Pauses authorization while retaining the captured draft and selection for an explicit retry.
    func cancelPendingNote() {
        guard isNoteAuthorizationPending, let pendingNoteDraft else {
            return
        }
        isNoteAuthorizationPending = false
        selectedVerses = pendingNoteDraft.selection
        showingVerseActionsDrawer = !selectedVerses.isEmpty
    }

    /// Requests dismissal, confirming only when the user has entered text.
    func requestDismissNote() {
        guard let noteDraft, !noteDraft.isSaving else {
            return
        }
        if noteDraft.hasTextChanges {
            noteDraft.showingDiscardConfirmation = true
        } else {
            discardNote()
        }
    }

    /// Discards this draft and clears the verse selection.
    func discardNote() {
        guard noteDraft?.isSaving != true else {
            return
        }
        noteDraft = nil
        removeVerseSelection()
    }

    /// Closes this draft without affecting a later composer.
    func finishNote(_ draft: BibleReaderNoteDraft) {
        guard noteDraft === draft else {
            return
        }
        noteDraft = nil
        removeVerseSelection()
    }
}
