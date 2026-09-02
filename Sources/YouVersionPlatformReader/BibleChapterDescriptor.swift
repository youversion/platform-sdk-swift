import YouVersionPlatformCore

/// Describes the chapter currently displayed by the reader. Handed to the
/// host-provided `chapterHeader` builder (see ``BibleReaderView``), which the
/// reader rebuilds whenever it navigates to a different chapter.
public struct BibleChapterDescriptor: Sendable {
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
