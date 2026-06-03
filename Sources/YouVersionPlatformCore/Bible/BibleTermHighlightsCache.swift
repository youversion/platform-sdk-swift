import Foundation
#if canImport(Observation)
import Observation
#endif

/// An observable store of term-level highlights (e.g. collectible terms) keyed by verse.
///
/// The reader observes this cache and renders a distinct background plus a tappable
/// link for each term. Hosts drive reveals incrementally — adding a term highlight
/// when its reading-time delay elapses causes the reader to display it.
@MainActor
#if canImport(Observation)
@Observable
#endif
public final class BibleTermHighlightsCache {

    // MARK: Singleton
    public static let shared = BibleTermHighlightsCache()

    // MARK: Observable State
    public private(set) var termHighlights: [BibleTermHighlight] = []

    // MARK: Init
    public init() {}

    // MARK: Queries
    /// Term highlights whose verse overlaps the given reference (e.g. a chapter).
    public func termHighlights(overlapping range: BibleReference) -> [BibleTermHighlight] {
        termHighlights.filter { $0.reference.overlaps(with: range) }
    }

    // MARK: Mutations
    /// Replaces the entire set of term highlights.
    public func setTermHighlights(_ highlights: [BibleTermHighlight]) {
        termHighlights = highlights
    }

    /// Adds term highlights, replacing any existing entry with the same `id`.
    public func addTermHighlights(_ highlights: [BibleTermHighlight]) {
        for highlight in highlights {
            termHighlights.removeAll { $0.id == highlight.id }
            termHighlights.append(highlight)
        }
    }

    /// Removes term highlights by their opaque `id`.
    public func removeTermHighlights(ids: [String]) {
        termHighlights.removeAll { ids.contains($0.id) }
    }

    /// Clears all term highlights (e.g. on sign-out).
    public func reset() {
        termHighlights.removeAll()
    }
}
