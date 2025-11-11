
import Foundation

/// A protocol for types that need to split abbreviations into letters and trailing numbers.
public protocol AbbreviationSplitting {}
public extension AbbreviationSplitting {
    /// Splits a text string into its letter prefix and trailing number suffix.
    /// - Parameter text: The text to split (e.g., "ESV" or "1984")
    /// - Returns: A tuple containing the letters and numbers portions
    func splitAbbreviation(_ text: String) -> (letters: String, numbers: String) {
        let pattern = /^(.*?)(\d+)$/
        if let match = text.firstMatch(of: pattern) {
            return (String(match.1), String(match.2))
        }
        return (text, "")
    }
}
