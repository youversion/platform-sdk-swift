import Foundation
#if canImport(Observation)
import Observation
#else
public protocol Observable {}
#endif

public protocol BibleVersionAPIClient: Sendable {
    func version(withId id: Int) async throws -> BibleVersion
}

/// Abstraction over Bible version lookup and download operations.
public protocol BibleVersionRepositoryProtocol: Sendable {
    /// Returns a cached version when one is already available locally.
    func versionIfCached(_ id: Int) async throws -> BibleVersion?

    /// Returns a Bible version, loading it when needed.
    func version(withId id: Int) async throws -> BibleVersion

    /// Downloads a version for offline access.
    func downloadVersion(withId id: Int) async throws

    /// Returns the current download status for a version.
    func downloadStatus(for id: Int) -> BibleVersionRepository.BibleVersionDownloadStatus

    /// Removes a version from every local cache.
    func removeVersion(withId versionId: Int) async

    /// Removes every locally stored version that is no longer permitted.
    func removeUnpermittedVersions(permittedIds: Set<Int>) async
}

public protocol BibleVersionCaching: Sendable {
    func version(withId id: Int) async -> BibleVersion?
    func addVersion(_ version: BibleVersion) async
    func removeVersion(withId versionId: Int) async
    func versionIsPresent(for id: Int) -> Bool
    func removeUnpermittedVersions(permittedIds: Set<Int>) async
}

public final class VersionClient: BibleVersionAPIClient {
    public init() {}

    public func version(withId id: Int) async throws -> BibleVersion {
        try await YouVersionAPI.Bible.version(versionId: id)
    }
}

public actor VersionMemoryCache: BibleVersionCaching {
    public init() {}

    private var cache: [Int: BibleVersion] = [:]

    public func version(withId id: Int) async -> BibleVersion? {
        cache[id]
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        false
    }

    public func addVersion(_ version: BibleVersion) async {
        cache[version.id] = version
    }

    public func removeVersion(withId versionId: Int) async {
        cache.removeValue(forKey: versionId)
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        let ids = cache.keys
        let idsToRemove = ids.filter { !permittedIds.contains($0) }
        for idToRemove in idsToRemove {
            cache.removeValue(forKey: idToRemove)
        }
    }
}

public actor VersionDiskCache: BibleVersionCaching {
    private let storage: BibleContentStorage

    public init(directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()) {
        self.storage = BibleContentStorage(storageKind: .cache, directoryProvider: directoryProvider)
    }

    public func version(withId id: Int) -> BibleVersion? {
        storage.decoded(BibleVersion.self, for: .versionMetadata(versionId: id))
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        false
    }

    public func addVersion(_ version: BibleVersion) async {
        let url = storage.url(for: .versionMetadata(versionId: version.id))
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let data = try? JSONEncoder().encode(version) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func removeVersion(withId versionId: Int) async {
        let url = storage.url(for: .versionDirectory(versionId: versionId))
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            YouVersionPlatformLogger.notice(
                "VersionDiskCache got error while removing: \(error.localizedDescription)",
                category: "VersionCache"
            )
        }
    }

    static func cachedVersions(
        directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()
    ) async -> [Int] {
        BibleContentStorage(storageKind: .cache, directoryProvider: directoryProvider).versionDirectoryIds
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        let cached = storage.versionDirectoryIds
        for id in cached where !permittedIds.contains(id) {
            YouVersionPlatformLogger.notice(
                "Removing cached Bible version \(id) because it is no longer permitted",
                category: "VersionCache"
            )
            await removeVersion(withId: id)
        }
    }
}

// TODO: this code is nearly identical to VersionDiskCache, but we can't inherit from an actor. DRY this.
// (Plus, both of these are nearly identical to the code of ChapterDownloadCache and ChapterDiskCache!)
public actor VersionDownloadCache: BibleVersionCaching {
    private let storage: BibleContentStorage

    public init(directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()) {
        self.storage = BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider)
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        storage.contains(.versionMetadata(versionId: id))
    }

    public func version(withId id: Int) -> BibleVersion? {
        storage.decoded(BibleVersion.self, for: .versionMetadata(versionId: id))
    }

    public func addVersion(_ version: BibleVersion) async {
        var directoryURL = storage.url(for: .versionDirectory(versionId: version.id))
        let metadataUrl = storage.url(for: .versionMetadata(versionId: version.id))

        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        // exclude it from iCloud backup
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directoryURL.setResourceValues(values)

        // save the metadata file inside there
        if let data = try? JSONEncoder().encode(version) {
            try? data.write(to: metadataUrl, options: .atomic)
        }
    }

    public func removeVersion(withId id: Int) {
        removeDownloadedVersionDirectory(id: id)
    }

    private func removeDownloadedVersionDirectory(id: Int) {
        let url = storage.url(for: .versionDirectory(versionId: id))
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            YouVersionPlatformLogger.notice(
                "VersionDownloadCache got error while removing: \(error.localizedDescription)",
                category: "VersionCache"
            )
        }
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) {
        let downloads = storage.versionDirectoryIds
        for downloadedId in downloads where !permittedIds.contains(downloadedId) {
            YouVersionPlatformLogger.notice(
                "Removing downloaded Bible version \(downloadedId) because it is no longer permitted",
                category: "VersionCache"
            )
            removeVersion(withId: downloadedId)
        }
    }

    public static var downloadedVersions: [Int] {
        downloadedVersions(directoryProvider: DefaultBibleContentDirectoryProvider())
    }

    static func downloadedVersions(directoryProvider: BibleContentDirectoryProviding) -> [Int] {
        BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider).versionDirectoryIds
    }

}

public actor BibleVersionRepository: Observable, BibleVersionRepositoryProtocol {

    public static let shared = BibleVersionRepository()

    private let apiClient: BibleVersionAPIClient
    private let memoryCache: BibleVersionCaching
    private let diskCache: BibleVersionCaching
    private let downloadCache: BibleVersionCaching

    private var inFlightTasks: [Int: Task<BibleVersion, Error>] = [:]

    public init(
        apiClient: BibleVersionAPIClient = VersionClient(),
        memoryCache: BibleVersionCaching = VersionMemoryCache(),
        diskCache: BibleVersionCaching = VersionDiskCache(),
        downloadCache: BibleVersionCaching = VersionDownloadCache()
    ) {
        self.apiClient = apiClient
        self.memoryCache = memoryCache
        self.diskCache = diskCache
        self.downloadCache = downloadCache
    }

    public func versionIfCached(_ id: Int) async throws -> BibleVersion? {
        if let cached = await memoryCache.version(withId: id) {
            return cached
        }

        if let cached = await diskCache.version(withId: id) {
            await memoryCache.addVersion(cached)
            return cached
        }

        if let downloaded = await downloadCache.version(withId: id) {
            await memoryCache.addVersion(downloaded)
            return downloaded
        }

        return nil
    }

    public func version(withId id: Int) async throws -> BibleVersion {
        do {
            if let version = try await versionIfCached(id) {
                return version
            }
        } catch {
            YouVersionPlatformLogger.error("BibleVersionRepository.version: \(error)", category: "VersionCache")
        }

        // If a fetch is already in-flight, await its result
        if let task = inFlightTasks[id] {
            return try await task.value
        }

        // Otherwise, create a new fetch task
        let task = Task { [apiClient, diskCache] in
            let version = try await apiClient.version(withId: id)
            await diskCache.addVersion(version)
            return version
        }

        inFlightTasks[id] = task

        defer {
            inFlightTasks[id] = nil
        }

        let version = try await task.value
        await memoryCache.addVersion(version)
        await diskCache.addVersion(version)
        return version
    }

    public func versionIsPresent(for id: Int) -> Bool {
        downloadCache.versionIsPresent(for: id)
    }

    public func downloadVersion(withId id: Int) async throws {
        if downloadCache.versionIsPresent(for: id) {
            return
        }

        let version = try await version(withId: id)
        await downloadCache.addVersion(version)
        await diskCache.removeVersion(withId: id)  // don't want to store 2 copies
    }

    public enum BibleVersionDownloadStatus: Sendable {
        case downloadable
        case downloaded
        case notDownloadable
    }

    nonisolated public func downloadStatus(for id: Int) -> BibleVersionDownloadStatus {
        if downloadCache.versionIsPresent(for: id) {
            return .downloaded
        }
        // TODO: look at the BibleVersion to see if it's downloadable or not.
        return .notDownloadable
    }

    public func removeVersion(withId versionId: Int) async {
        await memoryCache.removeVersion(withId: versionId)
        await diskCache.removeVersion(withId: versionId)
        await downloadCache.removeVersion(withId: versionId)
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        await memoryCache.removeUnpermittedVersions(permittedIds: permittedIds)
        await diskCache.removeUnpermittedVersions(permittedIds: permittedIds)
        await downloadCache.removeUnpermittedVersions(permittedIds: permittedIds)
    }
}
