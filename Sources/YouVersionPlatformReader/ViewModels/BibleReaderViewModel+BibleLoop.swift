import SwiftUI
import YouVersionPlatformCore

/// Bible Loop-specific reader behavior.
///
/// Kept in its own file, separate from the shared view model extensions, so that
/// this branch only differs from `main` by the call sites that invoke it.
extension BibleReaderViewModel {
    /// Opens the book picker with the current book already expanded, so its chapters
    /// are visible without a second tap. Closing leaves the expanded book untouched.
    func toggleBookPicker() {
        if !showingBookPicker {
            headerExpandedBookCode = reference.bookId
        }
        showingBookPicker.toggle()
    }
}
