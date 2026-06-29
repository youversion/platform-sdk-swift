import SwiftUI
import YouVersionPlatformCore

/// The information handed to a host-provided chapter-header builder
/// (see ``SwiftUICore/View/bibleReaderChapterHeader(_:)``). The reader resolves
/// these values for the chapter currently being displayed and rebuilds the
/// header whenever the reader navigates to a different chapter.
public struct BibleReaderChapterHeaderContext: Sendable {
    /// The chapter currently displayed.
    public let reference: BibleReference
    /// The localized, human-readable book name (e.g. "John"). Falls back to the
    /// book USFM code when no name is available.
    public let bookName: String
    /// The display label for the chapter, e.g. "1". Not guaranteed to be numeric —
    /// some versions use non-numeric chapter labels.
    public let chapterLabel: String

    public init(reference: BibleReference, bookName: String, chapterLabel: String) {
        self.reference = reference
        self.bookName = bookName
        self.chapterLabel = chapterLabel
    }
}

private func emptyChapterHeader(_ context: BibleReaderChapterHeaderContext) -> AnyView {
    AnyView(EmptyView())
}

private struct BibleReaderChapterHeaderKey: EnvironmentKey {
    static var defaultValue: (BibleReaderChapterHeaderContext) -> AnyView { emptyChapterHeader }
}

extension EnvironmentValues {
    var bibleReaderChapterHeader: (BibleReaderChapterHeaderContext) -> AnyView {
        get { self[BibleReaderChapterHeaderKey.self] }
        set { self[BibleReaderChapterHeaderKey.self] = newValue }
    }
}

public extension View {
    /// Supplies a per-chapter header the reader renders at the top of each chapter,
    /// above the verse text. The builder receives a ``BibleReaderChapterHeaderContext``
    /// (the chapter reference, book name, and chapter label) and is rebuilt whenever
    /// the reader navigates to a different chapter.
    ///
    /// Fonts, colors, and layout are entirely the host's; the reader owns placement
    /// and width. With no modifier applied, the reader shows no header.
    func bibleReaderChapterHeader<Header: View>(
        @ViewBuilder _ header: @escaping (BibleReaderChapterHeaderContext) -> Header
    ) -> some View {
        environment(\.bibleReaderChapterHeader) { AnyView(header($0)) }
    }
}
