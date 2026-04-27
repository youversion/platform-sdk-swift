import Foundation

public actor ChapterDiskCache {
    private let storage: BibleContentStorage

    public init(directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()) {
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
        let url = storage.url(for: .chapter(versionId: reference.versionId, usfm: chapterUSFM))
        do {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = content.data(using: .utf8) {
                try data.write(to: url, options: .atomic)
            } else {
                YouVersionPlatformLogger.notice("Failed to convert content to UTF-8 data for \(url)", category: "ChapterCache")
            }
        } catch {
            YouVersionPlatformLogger.notice("ChapterDiskCache failed to write data to \(url): \(error)", category: "ChapterCache")
        }
    }

    public func removeVersion(versionId: Int) async {
        let cacheURL = storage.url(for: .chaptersDirectory(versionId: versionId))
        do {
            try FileManager.default.removeItem(at: cacheURL)
        } catch {
            YouVersionPlatformLogger.notice(
                "ChapterDiskCache got error while removing: \(error.localizedDescription)",
                category: "ChapterCache"
            )
        }
    }
}

// TODO: this code is nearly identical to VersionDiskCache, but we can't inherit from an actor. DRY this.
// (Plus, both of these are nearly identical to the code of VersionDiskCache and VersionDownloadCache!)
public actor ChapterDownloadCache {
    private let storage: BibleContentStorage

    public init(directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()) {
        self.storage = BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider)
    }

    func chapterContent(withReference reference: BibleReference) -> String? {
        guard let chapterUSFM = reference.chapterUSFM else {
            return nil
        }
        return storage.string(for: .chapter(versionId: reference.versionId, usfm: chapterUSFM))
    }

    nonisolated public func chaptersArePresent(versionId: Int) -> Bool {
        storage.containsNonEmptyDirectory(.chaptersDirectory(versionId: versionId))
    }

    public func removeVersion(versionId: Int) async {
        let cacheURL = storage.url(for: .chaptersDirectory(versionId: versionId))
        do {
            try FileManager.default.removeItem(at: cacheURL)
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

    // TODO: add MRU functionality and a maximum number of entries to this memoryCache.
    private var memoryCache: [String: String] = [:]
    private var diskCache = ChapterDiskCache()
    private var downloadCache = ChapterDownloadCache()

    static func cacheKey(reference: BibleReference) -> String {
        "\(reference.versionId)_\(reference.chapterUSFM ?? "unknown")"
    }

    func removeChaptersFromMemoryCache(withId versionId: Int) {
        let prefix = "\(versionId)_"
        let keysToRemove = memoryCache.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
        }
    }

    public func chapter(withReference reference: BibleReference) async throws -> String {
        let cacheKey = Self.cacheKey(reference: reference)

        if let cachedContent = memoryCache[cacheKey] {
            return cachedContent
        }

        if let cachedContent = await diskCache.chapterContent(withReference: reference) {
            memoryCache[cacheKey] = cachedContent
            return cachedContent
        }

        if let cachedContent = await downloadCache.chapterContent(withReference: reference) {
            memoryCache[cacheKey] = cachedContent
            return cachedContent
        }

        let content = try await YouVersionAPI.Bible.chapter(reference: reference)

        memoryCache[cacheKey] = content
        await diskCache.addChapterContent(content, reference: reference)

        return content
    }

    func cachedChapter(withReference reference: BibleReference) throws -> String? {
        let cacheKey = Self.cacheKey(reference: reference)
        return memoryCache[cacheKey]
    }

    func chaptersArePresent(versionId: Int) -> Bool {
        downloadCache.chaptersArePresent(versionId: versionId)
    }

    @MainActor
    public func removeVersion(withId versionId: Int) async {
        await removeChaptersFromMemoryCache(withId: versionId)
        await diskCache.removeVersion(versionId: versionId)
        await downloadCache.removeVersion(versionId: versionId)
    }
}
