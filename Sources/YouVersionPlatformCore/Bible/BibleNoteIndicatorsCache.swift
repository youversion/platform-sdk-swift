import Foundation
#if canImport(Observation)
import Observation
#endif

/// Tracks which verses have user notes so the reader can display a pencil icon.
///
/// Clients populate this cache with USFM identifiers. The renderer checks
/// ``hasNote(for:)`` when composing verse text to decide whether to prepend
/// the note indicator icon.
@MainActor
#if canImport(Observation)
@Observable
#endif
public final class BibleNoteIndicatorsCache {

    public static let shared = BibleNoteIndicatorsCache()

    private(set) var indicatedUSFMs: Set<String> = []

    private init() {}

    /// Replace the full set of note indicators (typically on app launch).
    public func setIndicators(_ usfms: Set<String>) {
        indicatedUSFMs = usfms
    }

    /// Add a single indicator (after the user creates a note).
    public func addIndicator(for usfm: String) {
        indicatedUSFMs.insert(usfm)
    }

    /// Remove a single indicator (after the user deletes their last note for a verse).
    public func removeIndicator(for usfm: String) {
        indicatedUSFMs.remove(usfm)
    }

    /// Whether the given verse has at least one note.
    public func hasNote(for usfm: String) -> Bool {
        indicatedUSFMs.contains(usfm)
    }

    /// Remove all indicators (e.g., on sign-out).
    public func reset() {
        indicatedUSFMs.removeAll()
    }
}
