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
        notesAuthenticationDidChange()
        let references = BibleReference.referencesByMerging(references: Array(selectedVerses).sorted())
        guard !references.isEmpty else {
            return
        }
        guard (isSignedIn && hasNotesPermission) || YouVersionPlatformConfiguration.isSignInEnabled else {
            return
        }
        let draft: BibleReaderNoteDraft
        if let pendingNoteDraft, pendingNoteDraft.references == references {
            draft = pendingNoteDraft
        } else {
            draft = makeNoteDraft(references: Array(selectedVerses), referenceTitle: selectedVerseTitle)
        }
        showingVerseActionsDrawer = false
        if isSignedIn && hasNotesPermission {
            guard let signedInAccount, draft.bind(to: signedInAccount) else {
                return
            }
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

    /// Opens a new composer for the tapped verse, alongside its previously saved notes.
    func showNotes(for reference: BibleReference, notes: [YouVersionNote]) {
        guard isSignedIn && !notes.isEmpty else {
            return
        }
        let title = version?.displayTitle(for: reference, includesVersionAbbreviation: false) ?? reference.passageId
        showingVerseActionsDrawer = false
        noteDraft = makeNoteDraft(references: [reference], referenceTitle: title, savedNotes: notes)
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
        guard let signedInAccount, pendingNoteDraft.bind(to: signedInAccount) else {
            invalidateNoteDrafts()
            return
        }
        self.pendingNoteDraft = nil
        isNoteAuthorizationPending = false
        showingVerseActionsDrawer = false
        noteDraft = pendingNoteDraft
    }

    /// Clears drafts on account replacement or loss of access to their saved notes, preserving unbound selections.
    func notesAuthenticationDidChange() {
        if let noteDraft, signedInAccount == nil || noteDraft.account != signedInAccount ||
            (!noteDraft.savedNotes.isEmpty && !hasReadNotesPermission) {
            noteDraft.invalidate()
            self.noteDraft = nil
            removeVerseSelection()
        }
        if let pendingNoteDraft, pendingNoteDraft.account != nil && pendingNoteDraft.account != signedInAccount {
            pendingNoteDraft.invalidate()
            self.pendingNoteDraft = nil
            isNoteAuthorizationPending = false
        }
    }

    /// Invalidates all note state, including operations still awaiting authorization or the server.
    func invalidateNoteDrafts() {
        noteDraft?.invalidate()
        pendingNoteDraft?.invalidate()
        noteDraft = nil
        pendingNoteDraft = nil
        isNoteAuthorizationPending = false
    }

    private func makeNoteDraft(references: [BibleReference], referenceTitle: String, savedNotes: [YouVersionNote] = []) -> BibleReaderNoteDraft {
        BibleReaderNoteDraft(
            references: references, referenceTitle: referenceTitle, savedNotes: savedNotes,
            account: signedInAccount, currentAccount: { [weak self] in self?.signedInAccount }
        )
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

    /// Requests dismissal, confirming when any composer field has changed.
    func requestDismissNote() {
        guard let noteDraft, !noteDraft.isBusy else {
            return
        }
        if noteDraft.hasChanges {
            noteDraft.showingDiscardConfirmation = true
        } else {
            discardNote()
        }
    }

    /// Discards this draft and clears the verse selection.
    func discardNote() {
        guard noteDraft?.isBusy != true else {
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
