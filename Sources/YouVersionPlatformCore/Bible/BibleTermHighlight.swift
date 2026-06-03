import Foundation

/// A highlight applied to a specific term (word or phrase) within a verse, rather
/// than to a whole verse. Used to surface tappable collectible terms in the reader.
public struct BibleTermHighlight: CustomDebugStringConvertible, Sendable, Equatable, Identifiable {
    /// The verse the term appears in.
    public let reference: BibleReference
    /// The exact term to match within the verse text. Matching is case-insensitive,
    /// first occurrence.
    public let term: String
    /// A hex background color value for the highlight, e.g. "#E7F2FD".
    public let color: String
    /// An optional hex color for the term text itself, e.g. "#2A85F4". When `nil` the
    /// term keeps its surrounding scripture color.
    public let textColor: String?
    /// An opaque identifier the host can map back to its own model (e.g. a collectible id).
    /// Delivered verbatim to `onCollectibleTap` when the term is tapped.
    public let id: String

    public init(_ reference: BibleReference, term: String, color: String, textColor: String? = nil, id: String) {
        self.reference = reference
        self.term = term
        self.color = color
        self.textColor = textColor
        self.id = id
    }

    public var debugDescription: String {
        "\(reference) [\(term)] : \(color) (#\(id))"
    }

    /// Returns the range of the first case-insensitive occurrence of `term` within
    /// `text`, or `nil` if the term is empty or not present. Handles multi-word terms.
    public func firstMatchRange(in text: String) -> Range<String.Index>? {
        Self.firstMatchRange(of: term, in: text)
    }

    /// Finds the first case-insensitive, **whole-word** occurrence of `term` in `text`.
    /// The match must be bounded by non-alphanumeric characters (or string ends) on both
    /// sides, so a short term like "son" does not match inside "person". Internal
    /// whitespace in multi-word terms (e.g. "Sea of Galilee") is preserved.
    public static func firstMatchRange(of term: String, in text: String) -> Range<String.Index>? {
        guard !term.isEmpty else {
            return nil
        }
        var searchStart = text.startIndex
        while let range = text.range(of: term, options: .caseInsensitive, range: searchStart..<text.endIndex) {
            let precededByWordChar = range.lowerBound > text.startIndex
                && text[text.index(before: range.lowerBound)].isWordCharacter
            let followedByWordChar = range.upperBound < text.endIndex
                && text[range.upperBound].isWordCharacter
            if !precededByWordChar && !followedByWordChar {
                return range
            }
            guard range.lowerBound < text.endIndex else {
                break
            }
            searchStart = text.index(after: range.lowerBound)
        }
        return nil
    }

    /// Whether this highlight applies to the given verse (matching version, book,
    /// chapter, and start verse).
    public func appliesTo(verse reference: BibleReference) -> Bool {
        self.reference.versionId == reference.versionId
            && self.reference.bookUSFM == reference.bookUSFM
            && self.reference.chapter == reference.chapter
            && self.reference.verseStart == reference.verseStart
    }
}

private extension Character {
    /// A character that can be part of a word for boundary detection (letter or number).
    var isWordCharacter: Bool {
        isLetter || isNumber
    }
}
