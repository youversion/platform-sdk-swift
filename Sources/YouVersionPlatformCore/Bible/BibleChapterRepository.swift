import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

actor ChapterMemoryCache {
    private var cache: [String: String] = [:]

    init() {}

    func chapterContent(withReference reference: BibleReference) -> String? {
        cache[Self.cacheKey(reference: reference)]
    }

    func addChapterContent(_ content: String, reference: BibleReference) {
        cache[Self.cacheKey(reference: reference)] = content
    }

    func removeVersion(withId id: Int) {
        let prefix = "\(id)_"
        let keysToRemove = cache.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }

    private static func cacheKey(reference: BibleReference) -> String {
        "\(reference.versionId)_\(reference.chapterUSFM ?? "unknown")"
    }
}

/// Manages a medium-duration cache of Bible chapter data; it's not in-memory therefore will survive the app being terminated.
actor BibleChapterDiskCache {
    private let storage: BibleContentStorage

    init(directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()) {
        storage = BibleContentStorage(storageKind: .cache, directoryProvider: directoryProvider)
    }

    func chapterContent(withReference reference: BibleReference) -> String? {
        guard let chapterUSFM = reference.chapterUSFM else {
            return nil
        }
        return storage.string(for: .chapter(versionId: reference.versionId, usfm: chapterUSFM))
    }

    func addChapterContent(_ content: String, reference: BibleReference) {
        guard let chapterUSFM = reference.chapterUSFM else {
            return
        }
        do {
            try storage.writeString(content, to: .chapter(versionId: reference.versionId, usfm: chapterUSFM))
        } catch {
            YouVersionPlatformLogger.notice(
                "BibleChapterDiskCache failed to write data: \(error.localizedDescription)",
                category: "ChapterCache"
            )
        }
    }

    func removeVersion(withId id: Int) {
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

/// Manages the chapter files of Bible versions which the user chose to download, e.g. for offline usage.
actor BibleChapterDownloadCache {
    private let storage: BibleContentStorage

    init(directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()) {
        storage = BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider)
    }

    func chapterContent(withReference reference: BibleReference) -> String? {
        guard let chapterUSFM = reference.chapterUSFM else {
            return nil
        }
        return storage.string(for: .chapter(versionId: reference.versionId, usfm: chapterUSFM))
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
    func chapterContent(for reference: BibleReference) async throws -> String
}

final class BibleChapterContentAPI: BibleChapterContentProviding {
    init() {}

    func chapterContent(for reference: BibleReference) async throws -> String {
        try await YouVersionAPI.Bible.chapter(reference: reference)
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
        if let cachedContent = await memoryCache.chapterContent(withReference: reference) {
            return cachedContent
        }

        if let cachedContent = await diskCache.chapterContent(withReference: reference) {
            await memoryCache.addChapterContent(cachedContent, reference: reference)
            return cachedContent
        }

        if let cachedContent = await downloadCache.chapterContent(withReference: reference) {
            await memoryCache.addChapterContent(cachedContent, reference: reference)
            return cachedContent
        }

        let content = try await provider.chapterContent(for: reference)

        await memoryCache.addChapterContent(content, reference: reference)
        await diskCache.addChapterContent(content, reference: reference)

        return content
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
