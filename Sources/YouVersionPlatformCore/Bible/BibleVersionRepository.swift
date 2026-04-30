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

@available(*, deprecated, message: "Internal SDK type. This class will be removed in a future major version.")
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

    public func removeVersion(withId id: Int) async {
        cache.removeValue(forKey: id)
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        cache = cache.filter { permittedIds.contains($0.key) }
    }
}

/// VersionDiskCache manages a medium-duration cache of Bible version metadata; it's not in-memory therefore will survive the app being terminated.
@available(*, deprecated, message: "Internal SDK type. This class will be removed in a future major version.")
public actor VersionDiskCache: BibleVersionCaching {
    private let storage: BibleContentStorage

    public init() {
        self.init(directoryProvider: DefaultBibleContentDirectoryProvider())
    }

    init(directoryProvider: BibleContentDirectoryProviding) {
        self.storage = BibleContentStorage(storageKind: .cache, directoryProvider: directoryProvider)
    }

    public func version(withId id: Int) async -> BibleVersion? {
        storage.decoded(BibleVersion.self, for: .versionMetadata(versionId: id))
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        storage.contains(.versionMetadata(versionId: id))
    }

    public func addVersion(_ version: BibleVersion) async {
        do {
            try storage.writeEncoded(version, to: .versionMetadata(versionId: version.id))
        } catch {
            YouVersionPlatformLogger.notice(
                "VersionDiskCache failed to write metadata for \(version.id): \(error.localizedDescription)",
                category: "VersionCache"
            )
        }
    }

    public func removeVersion(withId id: Int) async {
        do {
            try storage.remove(.versionDirectory(versionId: id))
        } catch {
            YouVersionPlatformLogger.notice(
                "VersionDiskCache got error while removing: \(error.localizedDescription)",
                category: "VersionCache"
            )
        }
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

/// VersionDownloadCache manages the Bible versions which the user chose to download, e.g. for offline usage.
@available(*, deprecated, message: "Internal SDK type. This class will be removed in a future major version.")
public actor VersionDownloadCache: BibleVersionCaching {
    private let storage: BibleContentStorage

    public init() {
        self.init(directoryProvider: DefaultBibleContentDirectoryProvider())
    }

    init(directoryProvider: BibleContentDirectoryProviding) {
        self.storage = BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider)
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        storage.contains(.versionMetadata(versionId: id))
    }

    public func version(withId id: Int) async -> BibleVersion? {
        storage.decoded(BibleVersion.self, for: .versionMetadata(versionId: id))
    }

    public func addVersion(_ version: BibleVersion) async {
        do {
            try storage.writeEncoded(
                version,
                to: .versionMetadata(versionId: version.id),
                isExcludedFromBackup: true
            )
        } catch {
            YouVersionPlatformLogger.notice(
                "VersionDownloadCache failed to write metadata for \(version.id): \(error.localizedDescription)",
                category: "VersionCache"
            )
        }
    }

    public func removeVersion(withId id: Int) {
        do {
            try storage.remove(.versionDirectory(versionId: id))
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

    static func downloadedVersionIds(directoryProvider: BibleContentDirectoryProviding) -> [Int] {
        BibleContentStorage(storageKind: .download, directoryProvider: directoryProvider).versionDirectoryIds
    }

    /// Returns the IDs of Bible versions that have been downloaded for offline use, scanning the default app-support directory.
    public static var downloadedVersions: [Int] {
        downloadedVersionIds(directoryProvider: DefaultBibleContentDirectoryProvider())
    }
}

protocol BibleVersionProviding: Sendable {
    func version(withId id: Int) async throws -> BibleVersion
}

final class BibleVersionAPI: BibleVersionProviding {
    init() {}

    func version(withId id: Int) async throws -> BibleVersion {
        try await YouVersionAPI.Bible.version(versionId: id)
    }
}

public actor BibleVersionRepository: Observable, BibleVersionRepositoryProtocol {

    public static let shared = BibleVersionRepository()

    private let provider: BibleVersionProviding
    private let directoryProvider: BibleContentDirectoryProviding
    private let memoryCache: VersionMemoryCache
    private let diskCache: VersionDiskCache
    private let downloadCache: VersionDownloadCache

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
        self.memoryCache = VersionMemoryCache()
        self.diskCache = VersionDiskCache(directoryProvider: directoryProvider)
        self.downloadCache = VersionDownloadCache(directoryProvider: directoryProvider)
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
        let task = Task { [provider, memoryCache, diskCache] in
            let version = try await provider.version(withId: id)
            async let memory: Void = memoryCache.addVersion(version)
            async let disk: Void = diskCache.addVersion(version)
            _ = await (memory, disk)
            return version
        }

        inFlightTasks[id] = task

        defer {
            inFlightTasks[id] = nil
        }

        let version = try await task.value
        await memoryCache.addVersion(version)
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

    /// Returns the IDs for versions currently downloaded for offline use.
    nonisolated public var downloadedVersionIds: [Int] {
        VersionDownloadCache.downloadedVersionIds(directoryProvider: directoryProvider)
    }

    public func removeVersion(withId id: Int) async {
        async let memory: Void = memoryCache.removeVersion(withId: id)
        async let disk: Void = diskCache.removeVersion(withId: id)
        async let download: Void = downloadCache.removeVersion(withId: id)
        _ = await (memory, disk, download)
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        async let memory: Void = memoryCache.removeUnpermittedVersions(permittedIds: permittedIds)
        async let disk: Void = diskCache.removeUnpermittedVersions(permittedIds: permittedIds)
        async let download: Void = downloadCache.removeUnpermittedVersions(permittedIds: permittedIds)
        _ = await (memory, disk, download)
    }
}
