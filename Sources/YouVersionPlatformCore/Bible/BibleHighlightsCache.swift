import Foundation
import Observation

// MARK: - New Observable Cache Model

@MainActor
@Observable
public final class BibleHighlightsCache {

    // MARK: Singleton
    public static let shared = BibleHighlightsCache()

    // MARK: Types
    public enum CachedHighlightState: Equatable {
        case remoteSynced
        case localPendingCreate
        case localPendingUpdate
        case localPendingDelete
    }

    public struct CachedHighlight: Identifiable, Equatable {
        public let id: UUID
        public var highlight: BibleHighlight
        public var state: CachedHighlightState
        public var lastModifiedAt: Date

        public init(id: UUID = UUID(), highlight: BibleHighlight, state: CachedHighlightState, lastModifiedAt: Date = Date()) {
            self.id = id
            self.highlight = highlight
            self.state = state
            self.lastModifiedAt = lastModifiedAt
        }
    }

    // MARK: Observable State
    public var cachedHighlights: [CachedHighlight] = []

    // MARK: Throttling and Loading
    private var recentChapterFetches: [BibleReference: Date] = [:]
    private var currentlyLoadingChapters: Set<BibleReference> = []
    private let throttlingInterval: TimeInterval = 5 * 60

    // MARK: Init
    public init() {}

    // MARK: Public API - Queries
    public func highlights(overlapping range: BibleReference) -> [BibleHighlight] {
        cachedHighlights
            .filter { $0.highlight.reference.overlaps(with: range) }
            .map { $0.highlight }
    }

    public func hasRecentlyLoadedChapter(_ chapter: BibleReference) -> Bool {
        let chapterKey = normalizeToChapter(chapter)
        guard let lastFetch = recentChapterFetches[chapterKey] else {
            return false
        }
        return Date().timeIntervalSince(lastFetch) < throttlingInterval
    }

    public func isChapterLoading(_ chapter: BibleReference) -> Bool {
        currentlyLoadingChapters.contains(normalizeToChapter(chapter))
    }

    public func markChapterAsLoading(_ chapter: BibleReference) -> Bool {
        let normalized = normalizeToChapter(chapter)
        if currentlyLoadingChapters.contains(normalized) {
            return false
        }
        currentlyLoadingChapters.insert(normalized)
        return true
    }

    public func unmarkChapterAsLoading(_ chapter: BibleReference) {
        currentlyLoadingChapters.remove(normalizeToChapter(chapter))
    }

    public func recordChapterFetch(_ chapter: BibleReference, at date: Date = Date()) {
        recentChapterFetches[normalizeToChapter(chapter)] = date
    }

    // MARK: Public API - Mutations (write APIs preserved)
    public func addHighlights(_ highlights: [BibleHighlight]) {
        for highlight in highlights {
            // Remove any existing for same exact reference; then append as pending create
            cachedHighlights.removeAll { $0.highlight.reference == highlight.reference }
            cachedHighlights.append(
                CachedHighlight(highlight: highlight, state: .localPendingCreate)
            )
        }
    }

    public func removeHighlights(_ references: [BibleReference]) {
        for reference in references {
            // If there is a pending create for this reference, just drop it; otherwise mark pending delete
            if let idx = cachedHighlights.firstIndex(where: { $0.highlight.reference == reference && $0.state == .localPendingCreate }) {
                cachedHighlights.remove(at: idx)
            } else if let idx = cachedHighlights.firstIndex(where: { $0.highlight.reference == reference }) {
                cachedHighlights[idx].state = .localPendingDelete
                cachedHighlights[idx].lastModifiedAt = Date()
            }
        }
        // Optionally, physically remove localPendingDelete from visible list here if UI should hide deletes
        cachedHighlights.removeAll { $0.state == .localPendingDelete }
    }

    public func updateHighlightColors(_ references: [BibleReference], newColor: String) {
        for reference in references {
            if let idx = cachedHighlights.firstIndex(where: { $0.highlight.reference == reference }) {
                cachedHighlights[idx].highlight = BibleHighlight(reference, color: newColor)
                // Upgrade state to pending update unless it is a pending create
                if cachedHighlights[idx].state != .localPendingCreate {
                    cachedHighlights[idx].state = .localPendingUpdate
                }
                cachedHighlights[idx].lastModifiedAt = Date()
            } else {
                // Create if not exists, pending create
                cachedHighlights.append(
                    CachedHighlight(highlight: BibleHighlight(reference, color: newColor), state: .localPendingCreate)
                )
            }
        }
    }

    // MARK: Server Merge Helpers
    public func applyServerHighlights(for chapter: BibleReference, highlights: [BibleHighlight]) {
        let chapterRef = normalizeToChapter(chapter)

        // Remove existing remote-synced highlights for this chapter
        cachedHighlights.removeAll { ch in
            ch.state == .remoteSynced && ch.highlight.reference.bookUSFM == chapterRef.bookUSFM && ch.highlight.reference.chapter == chapterRef.chapter && ch.highlight.reference.versionId == chapterRef.versionId
        }

        // Append server highlights as remoteSynced
        for h in highlights {
            cachedHighlights.append(CachedHighlight(highlight: h, state: .remoteSynced))
        }
    }

    // MARK: Utilities
    private func normalizeToChapter(_ reference: BibleReference) -> BibleReference {
        BibleReference(versionId: reference.versionId, bookUSFM: reference.bookUSFM, chapter: reference.chapter)
    }

    // Called e.g. when the user signs out
    public func reset() {
        cachedHighlights.removeAll()
        recentChapterFetches.removeAll()
    }

}
