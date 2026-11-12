import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

public extension BibleTextView {
    /// Shows verse-number indicators for notes attached to this Bible version: blue normally, translucent gray over highlights.
    /// Loads all Notes pages for the displayed chapter while signed in with `read_notes`.
    /// Initial loading failures leave standard numbers in place; failed refreshes retain cached indicators.
    /// The callback receives the tapped reference and every matching note. No editor is presented.
    func withNoteIndicators(onSelected: @escaping (BibleReference, [YouVersionNote]) -> Void) -> some View {
        NoteIndicators(textView: self, onSelected: onSelected)
    }
}

private struct NoteIndicators: View {
    let textView: BibleTextView
    let onSelected: (BibleReference, [YouVersionNote]) -> Void
    @Environment(\.displayScale) private var displayScale
    @State private var model = BibleNoteIndicatorsModel()
    @State private var revision = UUID()

    var body: some View {
        textView.withVerseIndicators { reference in
            guard model.hasNotes(for: reference) else {
                return nil
            }
            let side = textView.textOptions.fontSize * 1.5
            let isHighlighted = !BibleHighlightsCache.shared.highlights(overlapping: reference).isEmpty
            return BibleVerseIndicatorStyle(
                backgroundColor: isHighlighted ? Color.gray.opacity(0.25) : Color(red: 0.35, green: 0.62, blue: 0.86).opacity(0.55),
                minimumHitTargetSize: CGSize(width: side, height: side),
                backgroundPadding: textView.textOptions.fontSize * 0.1 + 1 / displayScale,
                hasInlinePadding: true,
                foregroundColor: textView.textOptions.textColor ?? .primary,
                accessibilityLabel: "\(notesLabel) \(reference.verseStart.map(String.init) ?? reference.passageId)"
            )
        } onSelected: { reference in
            let notes = model.notes(for: reference)
            if !notes.isEmpty {
                onSelected(reference, notes)
            }
        }
        .task(id: LoadKey(reference: textView.reference.chapterReference, revision: revision)) {
            if model.canReadNotes {
                await model.load(textView.reference.chapterReference)
            } else {
                model.clear()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: YouVersionPlatformConfiguration.authDataDidChangeNotification).receive(on: RunLoop.main)) { _ in
            model.authorizationDidChange()
            revision = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .youVersionNotesChanged).receive(on: RunLoop.main)) { _ in
            revision = UUID()
        }
    }

    // TODO: Move new Notes accessibility copy to platform-localization when the Notes copy is localized.
    private var notesLabel: String { "Notes" }

    private struct LoadKey: Hashable {
        let reference: BibleReference
        let revision: UUID
    }
}

extension Notification.Name {
    static let youVersionNotesChanged = Notification.Name("YouVersionPlatform.NotesChanged")
}
