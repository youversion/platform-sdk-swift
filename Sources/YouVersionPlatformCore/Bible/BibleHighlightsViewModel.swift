import Foundation
#if canImport(SwiftUI)
import SwiftUI
#else
public protocol ObservableObject {}
#endif

// MARK: - Bible Highlights View Model

@MainActor
public class BibleHighlightsViewModel: ObservableObject {

    public static let shared = BibleHighlightsViewModel()

    private let cache: BibleHighlightsCache
    private let repository: any BibleHighlightsRepositoryProtocol
    private var loadTasks: [BibleReference: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    public init(
        cache: BibleHighlightsCache = BibleHighlightsCache.shared,
        repository: any BibleHighlightsRepositoryProtocol = BibleHighlightsRepository()
    ) {
        self.cache = cache
        self.repository = repository
    }

    // Called e.g. when the user signs out
    public func reset() {
        cache.reset()
    }
    
    // MARK: - Data Retrieval
    
    /// Synchronous method for getting highlights (views should observe cache directly and filter as needed)
    public func highlights(for range: BibleReference) -> [BibleHighlight] {
        cache.highlights(overlapping: range)
    }
    
    /// Ensure the chapter containing the range is loaded with throttling.
    public func ensureHighlightsForChapterLoaded(_ range: BibleReference, forceReload: Bool = false) {
        let chapterRef = BibleReference(versionId: range.versionId, bookUSFM: range.bookUSFM, chapter: range.chapter)
        guard forceReload || !cache.hasRecentlyLoadedChapter(chapterRef) else {
            return
        }
        guard cache.markChapterAsLoading(chapterRef) else {
            return
        }

        if loadTasks[chapterRef] != nil {
            return
        }

        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else {
                return
            }
            await self.loadChapterFromServer(chapterRef)
        }
        loadTasks[chapterRef] = task
    }

    // MARK: - CRUD Operations
    
    public func addHighlights(references: [BibleReference], color: String) {
        let highlights = references.map { reference in
            BibleHighlight(
                BibleReference(
                    versionId: reference.versionId,
                    bookUSFM: reference.bookUSFM,
                    chapter: reference.chapter,
                    verse: reference.verseStart ?? 1
                ),
                color: color
            )
        }

        // Add to cache immediately
        cache.addHighlights(highlights)

        // Queue for server
        let operation = PendingHighlightOperation(references: references, color: color, operationType: .add)
        repository.queueOperation(operation)
    }
    
    public func removeHighlights(references: [BibleReference]) {
        // Remove from cache immediately
        cache.removeHighlights(references)

        // Queue for server
        let operation = PendingHighlightOperation(references: references, color: nil, operationType: .remove)
        repository.queueOperation(operation)
    }
    
    public func updateHighlightColors(references: [BibleReference], newColor: String) {
        // Update in cache immediately
        cache.updateHighlightColors(references, newColor: newColor)

        // Queue for server
        let operation = PendingHighlightOperation(references: references, color: newColor, operationType: .update)
        repository.queueOperation(operation)
    }
    
    // MARK: - Private Helper Methods
    
    private func loadChapterFromServer(_ chapter: BibleReference) async {
        do {
            let serverHighlights = try await repository.highlights(for: [chapter])
            let chapterKey = "\(chapter.versionId)_\(chapter.bookUSFM)_\(chapter.chapter)"
            let highlights = serverHighlights[chapterKey] ?? []
            cache.applyServerHighlights(for: chapter, highlights: highlights)
            cache.recordChapterFetch(chapter)
        } catch {
            print("Failed to load highlights for chapter \(chapter): \(error)")
        }

        cache.unmarkChapterAsLoading(chapter)
        loadTasks.removeValue(forKey: chapter)
    }
}

// MARK: - Highlight Operation Types

public enum HighlightOperationType {
    case add
    case remove
    case update
}

// MARK: - Pending Highlight Operation

public struct PendingHighlightOperation: Identifiable {
    public let id: UUID
    public let references: [BibleReference]
    public let color: String?
    public let operationType: HighlightOperationType
    public let timestamp: Date

    public init(references: [BibleReference], color: String?, operationType: HighlightOperationType) {
        self.id = UUID()
        self.references = references
        self.color = color
        self.operationType = operationType
        self.timestamp = Date()
    }
}
