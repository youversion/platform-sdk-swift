import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

actor ChapterMemoryCache {
    private var cache: [String: CachedBibleContent<String>] = [:]

    init() {}

    func chapterContent(withReference reference: BibleReference, currentDate: Date) -> String? {
        let key = Self.cacheKey(reference: reference)
        guard let cached = cache[key] else {
            return nil
        }
        if let expirationDate = cached.expirationDate, expirationDate <= currentDate {
            cache[key] = nil
            return nil
        }
        return cached.value
    }

    func addChapterContent(_ content: String, reference: BibleReference, expirationDate: Date? = nil) {
        cache[Self.cacheKey(reference: reference)] = CachedBibleContent(
            value: content,
            expirationDate: expirationDate
        )
    }

    func removeVersion(withId id: Int) {
        let prefix = "\(id)_"
        let keysToRemove = cache.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }

    private static func cacheKey(reference: BibleReference) -> String {
        "\(reference.versionId)_\(reference.chapterPassageId)"
    }
}

/// Manages a medium-duration cache of Bible chapter data; it's not in-memory therefore will survive the app being terminated.
actor BibleChapterDiskCache {
    private let coordinator: BibleContentCacheCoordinator
    private let storage: BibleContentStorage

    init(
        directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider(),
        coordinator: BibleContentCacheCoordinator = .shared
    ) {
        self.coordinator = coordinator
        storage = BibleContentStorage(storageKind: .cache, directoryProvider: directoryProvider)
    }

    func chapterContent(withReference reference: BibleReference, currentDate: Date = Date()) async -> String? {
        await cachedChapterContent(withReference: reference, currentDate: currentDate)?.value
    }

    func cachedChapterContent(
        withReference reference: BibleReference,
        currentDate: Date
    ) async -> CachedBibleContent<String>? {
        let resource = BibleContentStorageResource.chapter(
            versionId: reference.versionId,
            chapterPassageId: reference.chapterPassageId
        )
        return await coordinator.perform {
            guard !storage.isExpired(resource, currentDate: currentDate) else {
                storage.removeCacheEntry(resource)
                return nil
            }
            guard let content = storage.string(for: resource) else {
                return nil
            }
            return CachedBibleContent(
                value: content,
                expirationDate: storage.expirationDate(for: resource)
            )
        }
    }

    func addChapterContent(_ content: String, reference: BibleReference, expirationDate: Date) async {
        let resource = BibleContentStorageResource.chapter(
            versionId: reference.versionId,
            chapterPassageId: reference.chapterPassageId
        )
        await coordinator.perform {
            do {
                try storage.writeExpirationDate(expirationDate, for: resource)
                try storage.writeString(
                    content,
                    to: resource
                )
            } catch {
                storage.removeCacheEntry(resource)
                YouVersionPlatformLogger.notice(
                    "BibleChapterDiskCache failed to write data: \(error.localizedDescription)",
                    category: "ChapterCache"
                )
            }
        }
    }

    func removeVersion(withId id: Int) async {
        await coordinator.perform {
            do {
                try storage.remove(.chaptersDirectory(versionId: id))
            } catch {
                YouVersionPlatformLogger.notice(
                    "BibleChapterDiskCache got error while removing: \(error.localizedDescription)",
                    category: "ChapterCache"
                )
            }
        }
    }
}

/// Manages the chapter files of Bible versions which the user chose to download, e.g. for offline usage.
actor BibleChapterDownloadCache {
    private let storage: BibleContentStorage

    init(directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()) {
        storage = BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider)
    }

    func chapterContent(withReference reference: BibleReference) -> String? {
        storage.string(
            for: .chapter(versionId: reference.versionId, chapterPassageId: reference.chapterPassageId)
        )
    }

    nonisolated func chaptersArePresent(versionId: Int) -> Bool {
        storage.containsNonEmptyDirectory(.chaptersDirectory(versionId: versionId))
    }

    func removeVersion(withId id: Int) {
        do {
            try storage.remove(.chaptersDirectory(versionId: id))
        } catch {
            YouVersionPlatformLogger.notice(
                "BibleChapterDownloadCache got error while removing: \(error.localizedDescription)",
                category: "ChapterCache"
            )
        }
    }
}

protocol BibleChapterContentProviding: Sendable {
    func chapterContent(for reference: BibleReference) async throws -> CachedBibleContent<String>
}

final class BibleChapterContentAPI: BibleChapterContentProviding {
    init() {}

    func chapterContent(for reference: BibleReference) async throws -> CachedBibleContent<String> {
        try await YouVersionAPI.Bible.chapterResponse(reference: reference)
    }
}

public actor BibleChapterRepository: ObservableObject {

    public static let shared = BibleChapterRepository()

    private let provider: BibleChapterContentProviding
    private let memoryCache: ChapterMemoryCache
    private let diskCache: BibleChapterDiskCache
    private let downloadCache: BibleChapterDownloadCache

    public init() {
        self.init(
            provider: BibleChapterContentAPI(),
            directoryProvider: DefaultBibleContentDirectoryProvider()
        )
    }

    init(
        provider: BibleChapterContentProviding,
        directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()
    ) {
        self.provider = provider
        self.memoryCache = ChapterMemoryCache()
        self.diskCache = BibleChapterDiskCache(directoryProvider: directoryProvider)
        self.downloadCache = BibleChapterDownloadCache(directoryProvider: directoryProvider)
    }

    public func chapter(withReference reference: BibleReference) async throws -> String {
        try await chapter(withReference: reference, currentDate: Date())
    }

    func chapter(withReference reference: BibleReference, currentDate: Date) async throws -> String {
        if let cachedContent = await memoryCache.chapterContent(
            withReference: reference,
            currentDate: currentDate
        ) {
            return cachedContent
        }

        if let cached = await diskCache.cachedChapterContent(
            withReference: reference,
            currentDate: currentDate
        ) {
            await memoryCache.addChapterContent(
                cached.value,
                reference: reference,
                expirationDate: cached.expirationDate
            )
            return cached.value
        }

        if let cachedContent = await downloadCache.chapterContent(withReference: reference) {
            await memoryCache.addChapterContent(cachedContent, reference: reference)
            return cachedContent
        }

        let response = try await provider.chapterContent(for: reference)
        let expirationDate = response.expirationDate
            ?? currentDate.addingTimeInterval(BibleContentCachePolicy.defaultDuration)

        await memoryCache.addChapterContent(
            response.value,
            reference: reference,
            expirationDate: expirationDate
        )

        if response.isCacheable {
            await diskCache.addChapterContent(
                response.value,
                reference: reference,
                expirationDate: expirationDate
            )
        }

        return response.value
    }

    func chaptersArePresent(versionId: Int) -> Bool {
        downloadCache.chaptersArePresent(versionId: versionId)
    }

    public func removeVersion(withId id: Int) async {
        async let memory: Void = memoryCache.removeVersion(withId: id)
        async let disk: Void = diskCache.removeVersion(withId: id)
        async let download: Void = downloadCache.removeVersion(withId: id)
        _ = await (memory, disk, download)
    }
}
