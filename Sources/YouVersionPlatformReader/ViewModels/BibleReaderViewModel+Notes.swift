import YouVersionPlatformCore
import YouVersionPlatformUI

extension BibleReaderViewModel {
    var selectedVerseTitle: String {
        let references = BibleReference.referencesByMerging(references: Array(selectedVerses).sorted())
        let titles = references.map { version?.displayTitle(for: $0, includesVersionAbbreviation: false) ?? $0.passageId }
        return titles.joined(separator: .localized("shareableVerse.referencesSeparator"))
    }

    /// Captures the selection and opens Notes only after sign-in and the current UX permission gate are satisfied.
    func startNote() {
        let references = BibleReference.referencesByMerging(references: Array(selectedVerses).sorted())
        guard !references.isEmpty else {
            return
        }
        guard isSignedIn || YouVersionPlatformConfiguration.isSignInEnabled else {
            return
        }
        let draft = BibleReaderNoteDraft(references: references, referenceTitle: selectedVerseTitle)
        showingVerseActionsDrawer = false
        if isSignedIn && hasNotesPermission {
            noteDraft = draft
        } else {
            pendingNoteDraft = draft
            if isSignedIn {
                startDataExchangeFlow = true
            } else {
                showingSignInSheet = true
            }
        }
    }

    /// Opens the captured draft when authentication and the current UX permission gate both succeeded.
    func continuePendingNote(with grantedPermissions: [String]) {
        guard let pendingNoteDraft else {
            return
        }
        guard isSignedIn && grantedPermissions.contains(Self.notesPermission) else {
            cancelPendingNote()
            return
        }
        self.pendingNoteDraft = nil
        showingVerseActionsDrawer = false
        noteDraft = pendingNoteDraft
    }

    /// Drops a deferred composer after login or permission consent is cancelled or denied.
    func cancelPendingNote() {
        guard pendingNoteDraft != nil else {
            return
        }
        pendingNoteDraft = nil
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
