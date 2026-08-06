import YouVersionPlatformCore

// Represents a footnote and its reference location.
public struct BibleFootnote: Hashable, Identifiable {
    public let id: String
    public let text: BibleAttributedString
    public let reference: BibleReference

    public init(text: BibleAttributedString, reference: BibleReference, id: String) {
        self.text = text
        self.reference = reference
        self.id = id
    }
}
