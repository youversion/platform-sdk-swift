import Foundation

actor ChapterMemoryCache {
    private var cache: [String: String] = [:]

    init() {}

    func chapterContent(withReference reference: BibleReference) async -> String? {
        cache[Self.cacheKey(reference: reference)]
    }

    func addChapterContent(_ content: String, reference: BibleReference) async {
        cache[Self.cacheKey(reference: reference)] = content
    }

    func removeVersion(versionId: Int) async {
        let prefix = "\(versionId)_"
        let keysToRemove = cache.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }

    private static func cacheKey(reference: BibleReference) -> String {
        "\(reference.versionId)_\(reference.chapterUSFM ?? "unknown")"
    }
}

actor ChapterDiskCache {
    private let storage: BibleContentStorage

    init() {
        self.init(directoryProvider: DefaultBibleContentDirectoryProvider())
    }

    init(directoryProvider: BibleContentDirectoryProviding) {
        self.storage = BibleContentStorage(storageKind: .cache, directoryProvider: directoryProvider)
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
                "ChapterDiskCache failed to write data: \(error.localizedDescription)",
                category: "ChapterCache"
            )
        }
    }

    func removeVersion(versionId: Int) async {
        do {
            try storage.remove(.chaptersDirectory(versionId: versionId))
        } catch {
            YouVersionPlatformLogger.notice(
                "ChapterDiskCache got error while removing: \(error.localizedDescription)",
                category: "ChapterCache"
            )
        }
    }
}

actor ChapterDownloadCache {
    private let storage: BibleContentStorage

    init() {
        self.init(directoryProvider: DefaultBibleContentDirectoryProvider())
    }

    init(directoryProvider: BibleContentDirectoryProviding) {
        self.storage = BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider)
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

    func removeVersion(versionId: Int) async {
        do {
            try storage.remove(.chaptersDirectory(versionId: versionId))
        } catch {
            YouVersionPlatformLogger.notice(
                "ChapterDownloadCache got error while removing: \(error.localizedDescription)",
                category: "ChapterCache"
            )
        }
    }

}

public actor BibleChapterRepository: ObservableObject {

    public static let shared = BibleChapterRepository()

    private let chapterContentFromAPI: @Sendable (BibleReference) async throws -> String
    private let memoryCache: ChapterMemoryCache
    private let diskCache: ChapterDiskCache
    private let downloadCache: ChapterDownloadCache

    public init() {
        self.init(
            chapterContentFromAPI: { try await YouVersionAPI.Bible.chapter(reference: $0) },
            directoryProvider: DefaultBibleContentDirectoryProvider()
        )
    }

    init(
        chapterContentFromAPI: @escaping @Sendable (BibleReference) async throws -> String,
        directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()
    ) {
        self.chapterContentFromAPI = chapterContentFromAPI
        self.memoryCache = ChapterMemoryCache()
        self.diskCache = ChapterDiskCache(directoryProvider: directoryProvider)
        self.downloadCache = ChapterDownloadCache(directoryProvider: directoryProvider)
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

        let content = try await chapterContentFromAPI(reference)

        await memoryCache.addChapterContent(content, reference: reference)
        await diskCache.addChapterContent(content, reference: reference)

        return content
    }

    func chaptersArePresent(versionId: Int) -> Bool {
        downloadCache.chaptersArePresent(versionId: versionId)
    }

    @MainActor
    public func removeVersion(withId versionId: Int) async {
        await memoryCache.removeVersion(versionId: versionId)
        await diskCache.removeVersion(versionId: versionId)
        await downloadCache.removeVersion(versionId: versionId)
    }
}
