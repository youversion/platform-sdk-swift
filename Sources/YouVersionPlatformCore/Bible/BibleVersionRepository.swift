import Foundation
#if canImport(Observation)
import Observation
#else
public protocol Observable {}
#endif

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
    func removeVersion(withId id: Int) async

    /// Removes every locally stored version that is no longer permitted.
    func removeUnpermittedVersions(permittedIds: Set<Int>) async
}

actor BibleVersionMemoryCache {
    init() {}

    private var cache: [Int: CachedBibleContent<BibleVersion>] = [:]

    func version(withId id: Int, currentDate: Date) -> BibleVersion? {
        guard let cached = cache[id] else {
            return nil
        }
        if let expirationDate = cached.expirationDate, expirationDate <= currentDate {
            cache[id] = nil
            return nil
        }
        return cached.value
    }

    func addVersion(_ version: BibleVersion, expirationDate: Date? = nil) {
        cache[version.id] = CachedBibleContent(value: version, expirationDate: expirationDate)
    }

    func removeVersion(withId id: Int) {
        cache.removeValue(forKey: id)
    }

    func removeUnpermittedVersions(permittedIds: Set<Int>) {
        cache = cache.filter { permittedIds.contains($0.key) }
    }
}

/// Manages a medium-duration cache of Bible version metadata; it's not in-memory therefore will survive the app being terminated.
actor BibleVersionDiskCache {
    private let storage: BibleContentStorage

    init(directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()) {
        self.storage = BibleContentStorage(storageKind: .cache, directoryProvider: directoryProvider)
    }

    func version(withId id: Int, currentDate: Date = Date()) -> BibleVersion? {
        cachedVersion(withId: id, currentDate: currentDate)?.value
    }

    func cachedVersion(withId id: Int, currentDate: Date) -> CachedBibleContent<BibleVersion>? {
        let resource = BibleContentStorageResource.versionMetadata(versionId: id)
        guard !storage.isExpired(resource, currentDate: currentDate) else {
            storage.removeCachedResource(resource)
            return nil
        }
        guard let version = storage.decoded(BibleVersion.self, for: resource) else {
            return nil
        }
        return CachedBibleContent(
            value: version,
            expirationDate: storage.expirationDate(for: resource)
        )
    }

    nonisolated func containsVersion(withId id: Int) -> Bool {
        storage.hasResource(.versionMetadata(versionId: id))
    }

    func addVersion(_ version: BibleVersion, expirationDate: Date) {
        let resource = BibleContentStorageResource.versionMetadata(versionId: version.id)
        do {
            try storage.writeEncoded(version, to: resource)
            try storage.writeExpirationDate(expirationDate, for: resource)
        } catch {
            storage.removeCachedResource(resource)
            YouVersionPlatformLogger.notice(
                "BibleVersionDiskCache failed to write metadata for \(version.id): \(error.localizedDescription)",
                category: "VersionCache"
            )
        }
    }

    func removeVersion(withId id: Int) {
        do {
            try storage.remove(.versionDirectory(versionId: id))
        } catch {
            YouVersionPlatformLogger.notice(
                "BibleVersionDiskCache got error while removing: \(error.localizedDescription)",
                category: "VersionCache"
            )
        }
    }

    func removeUnpermittedVersions(permittedIds: Set<Int>, currentDate: Date = Date()) {
        storage.removeExpiredCachedResources(currentDate: currentDate)
        let cached = storage.versionDirectoryIds
        for id in cached where !permittedIds.contains(id) {
            YouVersionPlatformLogger.notice(
                "Removing cached Bible version \(id) because it is no longer permitted",
                category: "VersionCache"
            )
            removeVersion(withId: id)
        }
    }
}

/// Manages the Bible versions which the user chose to download, e.g. for offline usage.
actor BibleVersionDownloadCache {
    private let storage: BibleContentStorage

    init(directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()) {
        self.storage = BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider)
    }

    nonisolated func containsVersion(withId id: Int) -> Bool {
        storage.hasResource(.versionMetadata(versionId: id))
    }

    func version(withId id: Int) -> BibleVersion? {
        storage.decoded(BibleVersion.self, for: .versionMetadata(versionId: id))
    }

    func addVersion(_ version: BibleVersion) {
        do {
            try storage.writeEncoded(
                version,
                to: .versionMetadata(versionId: version.id),
                isExcludedFromBackup: true
            )
        } catch {
            YouVersionPlatformLogger.notice(
                "BibleVersionDownloadCache failed to write metadata for \(version.id): \(error.localizedDescription)",
                category: "VersionCache"
            )
        }
    }

    func removeVersion(withId id: Int) {
        do {
            try storage.remove(.versionDirectory(versionId: id))
        } catch {
            YouVersionPlatformLogger.notice(
                "BibleVersionDownloadCache got error while removing: \(error.localizedDescription)",
                category: "VersionCache"
            )
        }
    }

    func removeUnpermittedVersions(permittedIds: Set<Int>) {
        let downloads = storage.versionDirectoryIds
        for downloadedId in downloads where !permittedIds.contains(downloadedId) {
            YouVersionPlatformLogger.notice(
                "Removing downloaded Bible version \(downloadedId) because it is no longer permitted",
                category: "VersionCache"
            )
            removeVersion(withId: downloadedId)
        }
    }

    static func downloadedVersionIds(directoryProvider: BibleContentDirectoryProviding) -> [Int] {
        BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider).versionDirectoryIds
    }

    /// Returns the IDs of Bible versions that have been downloaded for offline use, scanning the default app-support directory.
    static var downloadedVersions: [Int] {
        downloadedVersionIds(directoryProvider: DefaultBibleContentDirectoryProvider())
    }
}

protocol BibleVersionProviding: Sendable {
    func version(withId id: Int) async throws -> CachedBibleContent<BibleVersion>
}

final class BibleVersionAPI: BibleVersionProviding {
    init() {}

    func version(withId id: Int) async throws -> CachedBibleContent<BibleVersion> {
        try await YouVersionAPI.Bible.versionResponse(withId: id)
    }
}

public actor BibleVersionRepository: Observable, BibleVersionRepositoryProtocol {

    public static let shared = BibleVersionRepository()

    private let provider: BibleVersionProviding
    private let directoryProvider: BibleContentDirectoryProviding
    private let memoryCache: BibleVersionMemoryCache
    private let diskCache: BibleVersionDiskCache
    private let downloadCache: BibleVersionDownloadCache

    private var inFlightTasks: [Int: Task<BibleVersion, Error>] = [:]

    public init() {
        self.init(
            provider: BibleVersionAPI(),
            directoryProvider: DefaultBibleContentDirectoryProvider()
        )
    }

    init(
        provider: BibleVersionProviding,
        directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()
    ) {
        self.provider = provider
        self.directoryProvider = directoryProvider
        self.memoryCache = BibleVersionMemoryCache()
        self.diskCache = BibleVersionDiskCache(directoryProvider: directoryProvider)
        self.downloadCache = BibleVersionDownloadCache(directoryProvider: directoryProvider)
    }

    @available(*, deprecated, message: "The apiClient/memoryCache/diskCache/downloadCache parameters are no longer honored. Use init() instead; this initializer will be removed in a future major version.")
    public init(
        apiClient: BibleVersionAPIClient = VersionClient(),
        memoryCache: BibleVersionCaching = VersionMemoryCache(),
        diskCache: BibleVersionCaching = VersionDiskCache(),
        downloadCache: BibleVersionCaching = VersionDownloadCache()
    ) {
        self.init(
            provider: BibleVersionAPI(),
            directoryProvider: DefaultBibleContentDirectoryProvider()
        )
    }

    public func versionIfCached(_ id: Int) async throws -> BibleVersion? {
        try await versionIfCached(id, currentDate: Date())
    }

    func versionIfCached(_ id: Int, currentDate: Date) async throws -> BibleVersion? {
        if let cached = await memoryCache.version(withId: id, currentDate: currentDate) {
            return cached
        }

        if let cached = await diskCache.cachedVersion(withId: id, currentDate: currentDate) {
            await memoryCache.addVersion(cached.value, expirationDate: cached.expirationDate)
            return cached.value
        }

        if let downloaded = await downloadCache.version(withId: id) {
            await memoryCache.addVersion(downloaded)
            return downloaded
        }

        return nil
    }

    public func version(withId id: Int) async throws -> BibleVersion {
        try await version(withId: id, currentDate: Date())
    }

    func version(withId id: Int, currentDate: Date) async throws -> BibleVersion {
        do {
            if let version = try await versionIfCached(id, currentDate: currentDate) {
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
        let task = Task { [provider, memoryCache, diskCache] in
            let response = try await provider.version(withId: id)
            if response.isCacheable {
                let expirationDate = response.expirationDate
                    ?? currentDate.addingTimeInterval(BibleContentCachePolicy.defaultDuration)
                async let memory: Void = memoryCache.addVersion(response.value, expirationDate: expirationDate)
                async let disk: Void = diskCache.addVersion(response.value, expirationDate: expirationDate)
                _ = await (memory, disk)
            }
            return response.value
        }

        inFlightTasks[id] = task

        defer {
            inFlightTasks[id] = nil
        }

        return try await task.value
    }

    public func containsVersion(withId id: Int) -> Bool {
        downloadCache.containsVersion(withId: id)
    }

    @available(*, deprecated, renamed: "containsVersion(withId:)")
    public func versionIsPresent(for id: Int) -> Bool {
        containsVersion(withId: id)
    }

    public func downloadVersion(withId id: Int) async throws {
        if downloadCache.containsVersion(withId: id) {
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
        if downloadCache.containsVersion(withId: id) {
            return .downloaded
        }
        // TODO: look at the BibleVersion to see if it's downloadable or not.
        return .notDownloadable
    }

    /// Returns the IDs for versions currently downloaded for offline use.
    nonisolated public var downloadedVersionIds: [Int] {
        BibleVersionDownloadCache.downloadedVersionIds(directoryProvider: directoryProvider)
    }

    /// Returns the IDs of Bible versions that have been downloaded for offline use, scanning the default app-support directory.
    package static var defaultDownloadedVersionIds: [Int] {
        BibleVersionDownloadCache.downloadedVersions
    }

    public func removeVersion(withId id: Int) async {
        async let memory: Void = memoryCache.removeVersion(withId: id)
        async let disk: Void = diskCache.removeVersion(withId: id)
        async let download: Void = downloadCache.removeVersion(withId: id)
        _ = await (memory, disk, download)
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        await removeUnpermittedVersions(permittedIds: permittedIds, currentDate: Date())
    }

    func removeUnpermittedVersions(permittedIds: Set<Int>, currentDate: Date) async {
        async let memory: Void = memoryCache.removeUnpermittedVersions(permittedIds: permittedIds)
        async let disk: Void = diskCache.removeUnpermittedVersions(
            permittedIds: permittedIds,
            currentDate: currentDate
        )
        async let download: Void = downloadCache.removeUnpermittedVersions(permittedIds: permittedIds)
        _ = await (memory, disk, download)
    }
}
