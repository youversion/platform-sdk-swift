// TODO: Move Notes copy to platform-localization and use String.localized after its sync.
enum NoteStrings {
    static let previouslySaved = "Previously Saved"
    static let addedNote = "You added a note on"
    static let replaceTitle = "Replace unsaved changes?"
    static let replaceMessage = "Your unsaved changes will be discarded when you open this saved note."
    static let replace = "Replace"
    static let delete = "Delete"
    static let deleteTitle = "Delete saved note?"
    static let deleteMessage = "This note will be permanently deleted. Your unsaved note text will be kept."
    static let save = "Save"
    static let privateVisibility = "Private"
    static let publicVisibility = "Public"
    static let placeholder = "Add Note…"
    static let discardTitle = "Discard note?"
    static let discardMessage = "Your note hasn’t been saved. Discard your changes?"
    static let discard = "Discard"

    /// The VoiceOver label for a verse indicator that opens saved notes.
    static func verseIndicatorAccessibilityLabel(verse: String) -> String {
        "Notes \(verse)"
    }
}
