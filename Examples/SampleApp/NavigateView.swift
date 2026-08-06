import SwiftUI
import YouVersionPlatform

/// Demonstrates driving the Bible reader from another tab via
/// ``BibleReaderNavigation``: each button requests a passage and switches to the
/// Bible tab, where the shared reader moves to it in place.
struct NavigateView: View {
    let navigation: BibleReaderNavigation
    let onNavigate: () -> Void

    private let examples: [(title: String, reference: BibleReference, showsFullChapter: Bool, shouldFocus: Bool)] = [
        (
            "John 3:16 — full chapter, scrolled to the verse",
            BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16),
            true,
            false
        ),
        (
            "John 3:16 — focused",
            BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16),
            true,
            true
        ),
        (
            "Psalm 119:105 — full chapter, scrolled to the verse",
            BibleReference(versionId: 3034, bookId: "PSA", chapter: 119, verse: 105),
            true,
            false
        ),
        (
            "Romans 8:28 — just the verse range",
            BibleReference(versionId: 3034, bookId: "ROM", chapter: 8, verse: 28),
            false,
            false
        ),
        (
            "Genesis 1 — whole chapter",
            BibleReference(versionId: 3034, bookId: "GEN", chapter: 1),
            true,
            false
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(examples, id: \.title) { example in
                        Button(example.title) {
                            if example.shouldFocus, #available(iOS 18.0, *) {
                                navigation.focusReference(example.reference)
                            } else {
                                navigation.request(example.reference, showsFullChapter: example.showsFullChapter)
                            }
                            onNavigate()
                        }
                    }
                } footer: {
                    Text("Tapping a passage drives the reader in the Bible tab — it isn't recreated.")
                }
            }
            .navigationTitle("Navigate")
        }
    }
}
