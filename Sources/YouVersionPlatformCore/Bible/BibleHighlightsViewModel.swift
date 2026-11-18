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
    nonisolated(unsafe) private var authStateObserver: NSObjectProtocol?

    // MARK: - Initialization

    public init(
        cache: BibleHighlightsCache = BibleHighlightsCache.shared,
        repository: any BibleHighlightsRepositoryProtocol = BibleHighlightsRepository()
    ) {
        self.cache = cache
        self.repository = repository
        self.authStateObserver = NotificationCenter.default.addObserver(
            forName: YouVersionPlatformConfiguration.authStateDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reset()
            }
        }
    }

    deinit {
        if let authStateObserver {
            NotificationCenter.default.removeObserver(authStateObserver)
        }
    }

    // Called e.g. when the user signs out
    public func reset() {
        cache.reset()
        (repository as? any BibleHighlightsPendingOperationsClearing)?.clearPendingOperations()
    }
    
    public var hasPendingOperations: Bool {
        (repository as? any BibleHighlightsPendingOperationsReporting)?.hasPendingOperations ?? false
    }
    
    // MARK: - Data Retrieval
    
    /// Synchronous method for getting highlights (views should observe cache directly and filter as needed)
    public func highlights(for range: BibleReference) -> [BibleHighlight] {
        cache.highlights(overlapping: range)
    }
    
    /// Ensure the chapter containing the range is loaded with throttling.
    public func ensureHighlightsForChapterLoaded(_ range: BibleReference, forceReload: Bool = false) {
        let chapterRef = BibleReference(versionId: range.versionId, bookId: range.bookId, chapter: range.chapter)
        guard forceReload || !cache.hasRecentlyLoadedChapter(chapterRef) else {
            return
        }
        guard cache.markChapterAsLoading(chapterRef) else {
            if forceReload {
                cache.queueChapterReload(chapterRef)
            }
            return
        }

        let generation = cache.loadGeneration
        Task {
            guard cache.loadGeneration == generation else {
                return
            }
            await loadChapterFromServer(chapterRef, generation: generation)
        }
    }

    // MARK: - CRUD Operations
    
    public func addHighlights(references: [BibleReference], color: String) {
        let highlights = references.map { reference in
            BibleHighlight(
                BibleReference(
                    versionId: reference.versionId,
                    bookId: reference.bookId,
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
    
    private func loadChapterFromServer(_ chapter: BibleReference, generation: Int) async {
        defer {
            if cache.loadGeneration == generation {
                cache.unmarkChapterAsLoading(chapter)
                if cache.takeQueuedChapterReload(chapter) {
                    ensureHighlightsForChapterLoaded(chapter, forceReload: true)
                }
            }
        }
        do {
            let serverHighlights = try await repository.highlights(for: [chapter])
            guard cache.loadGeneration == generation else {
                return
            }
            let chapterKey = "\(chapter.versionId)_\(chapter.bookId)_\(chapter.chapter)"
            if !cache.hasQueuedChapterReload(chapter), let highlights = serverHighlights[chapterKey] {
                cache.applyServerHighlights(for: chapter, highlights: highlights)
                cache.recordChapterFetch(chapter)
            }
        } catch {
            YouVersionPlatformLogger.error(
                "Failed to load highlights for chapter \(chapter): \(error)",
                category: "Highlights"
            )
        }
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
