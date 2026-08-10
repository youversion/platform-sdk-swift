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
            String(localized: "navigate.john_3_16_full_chapter"),
            BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16),
            true,
            false
        ),
        (
            String(localized: "navigate.john_3_16_focused"),
            BibleReference(versionId: 3034, bookId: "JHN", chapter: 3, verse: 16),
            true,
            true
        ),
        (
            String(localized: "navigate.psalm_119_105_full_chapter"),
            BibleReference(versionId: 3034, bookId: "PSA", chapter: 119, verse: 105),
            true,
            false
        ),
        (
            String(localized: "navigate.romans_8_28_verse_range"),
            BibleReference(versionId: 3034, bookId: "ROM", chapter: 8, verse: 28),
            false,
            false
        ),
        (
            String(localized: "navigate.genesis_1_whole_chapter"),
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
                    Text("navigate.footer")
                }
            }
            .navigationTitle("navigate.title")
        }
    }
}
