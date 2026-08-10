import Foundation

/// A highlight applied to a specific term (word or phrase) within a verse, rather
/// than to a whole verse. Used to surface tappable collectible terms in the reader.
public struct BibleTermHighlight: CustomDebugStringConvertible, Sendable, Equatable, Identifiable {
    /// The verse the term appears in.
    public let reference: BibleReference
    /// The term to match within the verse text. Matching is case-insensitive and
    /// insensitive to quote shape, first occurrence.
    public let term: String
    /// A hex background color value for the highlight, e.g. "#E7F2FD".
    public let color: String
    /// An optional hex color for the term text itself, e.g. "#2A85F4". Used in light
    /// reader themes and as the fallback. When `nil` the term keeps its surrounding
    /// scripture color.
    public let textColor: String?
    /// An optional hex color for the term text in dark reader themes, e.g. "#8FD7FF".
    /// When `nil`, `textColor` is used in both themes. Resolved at render time so the
    /// term recolors live when the reader theme changes.
    public let textColorDark: String?
    /// An opaque identifier the host can map back to its own model (e.g. a collectible id).
    /// Delivered verbatim to `onCollectibleTap` when the term is tapped.
    public let id: String

    /// Original initializer — preserved unchanged for API stability. The term keeps the
    /// same text color in both reader themes.
    public init(_ reference: BibleReference, term: String, color: String, textColor: String? = nil, id: String) {
        self.init(reference, term: term, color: color, textColor: textColor, textColorDark: nil, id: id)
    }

    /// Initializer that also supplies a dark-theme text color, resolved at render time.
    public init(_ reference: BibleReference, term: String, color: String, textColor: String?, textColorDark: String?, id: String) {
        self.reference = reference
        self.term = term
        self.color = color
        self.textColor = textColor
        self.textColorDark = textColorDark
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
    ///
    /// A term containing a quote also matches text that uses the opposite quote shape,
    /// so a term written with a straight apostrophe (`lions'`) matches verse text
    /// rendered with a typographic one (`lions’`), and vice versa. The returned range
    /// always indexes `text`.
    public static func firstMatchRange(of term: String, in text: String) -> Range<String.Index>? {
        guard !term.isEmpty else {
            return nil
        }
        if let range = wholeWordRange(of: term, in: text, using: foundationRange) {
            return range
        }
        guard term.contains(where: \.isQuote) else {
            return nil
        }
        return wholeWordRange(of: term, in: text, using: quoteFoldedRange)
    }

    /// Walks candidate matches produced by `nextRange`, returning the first bounded by
    /// non-word characters on both sides.
    private static func wholeWordRange(
        of term: String,
        in text: String,
        using nextRange: (String, String, String.Index) -> Range<String.Index>?
    ) -> Range<String.Index>? {
        var searchStart = text.startIndex
        while searchStart < text.endIndex, let range = nextRange(term, text, searchStart) {
            let precededByWordChar = range.lowerBound > text.startIndex
                && text[text.index(before: range.lowerBound)].isWordCharacter
            let followedByWordChar = range.upperBound < text.endIndex
                && text[range.upperBound].isWordCharacter
            if !precededByWordChar && !followedByWordChar {
                return range
            }
            searchStart = text.index(after: range.lowerBound)
        }
        return nil
    }

    /// Foundation's case-insensitive search, which applies full Unicode case folding
    /// (so `straße` matches `STRASSE`) but compares quote shapes literally.
    private static func foundationRange(of term: String, in text: String, from searchStart: String.Index) -> Range<String.Index>? {
        text.range(of: term, options: .caseInsensitive, range: searchStart..<text.endIndex)
    }

    /// Scans forward for the first occurrence of `term` comparing quote shapes as equal.
    /// Used only when Foundation finds nothing and the term contains a quote.
    private static func quoteFoldedRange(of term: String, in text: String, from searchStart: String.Index) -> Range<String.Index>? {
        var candidate = searchStart
        while candidate < text.endIndex {
            if let end = matchEnd(of: term, in: text, startingAt: candidate) {
                return candidate..<end
            }
            candidate = text.index(after: candidate)
        }
        return nil
    }

    /// Returns the index just past `term` when it matches `text` starting exactly at
    /// `start`, or `nil` if it does not. Comparison folds quote shapes and case.
    private static func matchEnd(of term: String, in text: String, startingAt start: String.Index) -> String.Index? {
        var textIndex = start
        for termCharacter in term {
            guard textIndex < text.endIndex,
                  text[textIndex].isEquivalent(to: termCharacter) else {
                return nil
            }
            textIndex = text.index(after: textIndex)
        }
        return textIndex
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

    /// Whether this character is a quote in any of the shapes `quoteFolded` collapses.
    var isQuote: Bool {
        quoteFolded == "'" || quoteFolded == "\""
    }

    /// The straight equivalent of a typographic quote, so apostrophes and quotation
    /// marks compare equal regardless of which form the source text uses.
    var quoteFolded: Character {
        switch self {
        case "\u{2018}", "\u{2019}", "\u{02BC}", "\u{FF07}":
            return "'"
        case "\u{201C}", "\u{201D}", "\u{FF02}":
            return "\""
        default:
            return self
        }
    }

    /// Whether two characters match for term searching, ignoring case and quote shape.
    func isEquivalent(to other: Character) -> Bool {
        let folded = quoteFolded
        let otherFolded = other.quoteFolded
        return folded == otherFolded || folded.lowercased() == otherFolded.lowercased()
    }
}
