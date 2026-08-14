import SwiftUI
import YouVersionPlatform

/// Visual QA grid for `BibleTextView` footnote highlights and focus dimming.
/// Each cell shows Psalm 118:1–3 (BSB). Verse 2 is highlighted and contains
/// the footnote; verses 1 and 3 are unhighlighted controls.
struct BibleTextGalleryView: View {
    private static let passage = BibleReference(
        versionId: 3034,
        bookId: "PSA",
        chapter: 118,
        verseStart: 1,
        verseEnd: 3
    )
    private static let verse2 = BibleReference(versionId: 3034, bookId: "PSA", chapter: 118, verse: 2)
    private static let fontSizes: [CGFloat] = [12, 16, 22]
    private static let lightTheme = ReaderTheme.theme(withId: 1)
    private static let darkTheme = ReaderTheme.theme(withId: 7)

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isVerse2Highlighted = true
    @State private var showsMultipleSizes = false

    private var visibleFontSizes: [CGFloat] {
        showsMultipleSizes ? Self.fontSizes : [12]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 24) {
                        Toggle("Highlight v2", isOn: $isVerse2Highlighted)
                        Toggle("multiple sizes", isOn: $showsMultipleSizes)
                    }
                    .toggleStyle(.switch)
                    Text("Verse 2 has the footnote. Yellow highlight is on v2 when the toggle is on. Verses 1 and 3 stay unhighlighted.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 16) {
                            themeColumn(for: Self.lightTheme)
                            themeColumn(for: Self.darkTheme)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            themeColumn(for: Self.lightTheme)
                            themeColumn(for: Self.darkTheme)
                        }
                    }
                }
                .padding()
                .id(isVerse2Highlighted)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Psalm 118:1–3 BSB")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: isVerse2Highlighted, initial: true) { _, isHighlighted in
                applyHighlight(isHighlighted)
            }
        }
    }

    private func themeColumn(for theme: ReaderTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(theme.colorScheme == .dark ? "Dark" : "Light")
                .font(.headline)
            ForEach(FocusVariant.allCases) { focus in
                VStack(alignment: .leading, spacing: 8) {
                    Text(focus.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if showsMultipleSizes {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            fontSizeCells(theme: theme, focus: focus)
                        }
                    } else {
                        fontSizeCells(theme: theme, focus: focus)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func fontSizeCells(theme: ReaderTheme, focus: FocusVariant) -> some View {
        ForEach(visibleFontSizes, id: \.self) { fontSize in
            BibleTextGalleryCell(
                passage: Self.passage,
                theme: theme,
                fontSize: fontSize,
                focusedReference: focus.focusedReference
            )
        }
    }

    private func applyHighlight(_ isHighlighted: Bool) {
        if isHighlighted {
            BibleHighlightsCache.shared.addHighlights([
                BibleHighlight(Self.verse2, color: "fffe00")
            ])
        } else {
            BibleHighlightsCache.shared.removeHighlights([Self.verse2])
        }
    }
}

private struct BibleTextGalleryCell: View {
    let passage: BibleReference
    let theme: ReaderTheme
    let fontSize: CGFloat
    let focusedReference: BibleReference?

    private var verseNumberColor: Color {
        theme.colorScheme == .dark ? Color(hex: "#636161") : Color(hex: "#9d9d9d")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Int(fontSize))pt")
                .font(.caption2)
                .foregroundStyle(theme.foreground.opacity(0.6))
            BibleTextView(
                passage,
                textOptions: BibleTextOptions(
                    fontSize: fontSize,
                    textColor: theme.foreground,
                    verseNumberColor: verseNumberColor,
                    footnoteMode: .image
                ),
                selectedVerses: .constant([]),
                focusedReference: focusedReference
            )
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background)
        .environment(\.colorScheme, theme.colorScheme)
        .preferredColorScheme(theme.colorScheme)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.35))
        )
    }
}

private enum FocusVariant: String, CaseIterable, Identifiable {
    case none
    case verse1
    case verse2

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            "No focus"
        case .verse1:
            "Focus v1 · dim highlighted footnote"
        case .verse2:
            "Focus v2 · dim unhighlighted verses"
        }
    }

    var focusedReference: BibleReference? {
        switch self {
        case .none:
            nil
        case .verse1:
            BibleReference(versionId: 3034, bookId: "PSA", chapter: 118, verse: 1)
        case .verse2:
            BibleReference(versionId: 3034, bookId: "PSA", chapter: 118, verse: 2)
        }
    }
}

#Preview {
    BibleTextGalleryView()
}
