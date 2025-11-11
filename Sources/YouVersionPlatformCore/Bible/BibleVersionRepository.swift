import Foundation
#if canImport(Observation)
import Observation
#else
public protocol Observable {}
#endif

public protocol BibleVersionAPIClient: Sendable {
    func version(withId id: Int) async throws -> BibleVersion
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

func scanForVersionsIn(dir: URL) -> [Int] {
    let urls = (try? FileManager.default.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )) ?? []

    var ids: [Int] = []
    let prefix = "bible_"

    for url in urls {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
            values.isDirectory == true {
            let name = url.lastPathComponent
            if name.hasPrefix(prefix) {
                let suffix = String(name.dropFirst(prefix.count))
                let isAllDigits = suffix.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
                if isAllDigits, suffix.count < 7, let id = Int(suffix) {
                    ids.append(id)
                }
            }
        }
    }
    return ids
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
    public init() {}

    static func urlForCachedVersionMetadata(_ versionId: Int) -> URL {
        urlForBibleContentDirectory(versionId: versionId, kind: .cachesDirectory)
            .appending(path: "metadata", directoryHint: .notDirectory)
    }

    public func version(withId id: Int) -> BibleVersion? {
        let url = Self.urlForCachedVersionMetadata(id)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        print("loading version \(id) from \(url)")
        return try? JSONDecoder().decode(BibleVersion.self, from: data)
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        false
    }

    public func addVersion(_ version: BibleVersion) async {
        let url = Self.urlForCachedVersionMetadata(version.id)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let data = try? JSONEncoder().encode(version) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func removeVersion(withId versionId: Int) async {
        let url = urlForBibleContentDirectory(versionId: versionId, kind: .cachesDirectory)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("VersionDiskCache got error while removing: \(error.localizedDescription)")
        }
    }

    static func cachedVersions() async -> [Int] {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return []
        }
        return scanForVersionsIn(dir: dir)
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        let cached: [Int] = Array(await Self.cachedVersions().compactMap(\.self) )
        for id in cached where !permittedIds.contains(id) {
            print("Removing cached Bible version \(id) because it is no longer permitted")
            await removeVersion(withId: id)
        }
    }
}

// TODO: this code is nearly identical to VersionDiskCache, but we can't inherit from an actor. DRY this.
// (Plus, both of these are nearly identical to the code of ChapterDownloadCache and ChapterDiskCache!)
public actor VersionDownloadCache: BibleVersionCaching {
    public init() {}

    static func urlForDownloadedVersion(_ versionId: Int) -> URL {
        urlForBibleContentDirectory(versionId: versionId, kind: .applicationSupportDirectory)
            .appending(path: "metadata", directoryHint: .notDirectory)
    }

    nonisolated public func versionIsPresent(for id: Int) -> Bool {
        let url = Self.urlForDownloadedVersion(id)
        let ret = FileManager.default.fileExists(atPath: url.path)
        return ret
    }

    public func version(withId id: Int) -> BibleVersion? {
        let url = Self.urlForDownloadedVersion(id)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(BibleVersion.self, from: data)
    }

    public func addVersion(_ version: BibleVersion) async {
        var directoryURL = urlForBibleContentDirectory(versionId: version.id, kind: .applicationSupportDirectory)
        let metadataUrl = Self.urlForDownloadedVersion(version.id)

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
        let url = urlForBibleContentDirectory(versionId: id, kind: .applicationSupportDirectory)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("VersionDownloadCache got error while removing: \(error.localizedDescription)")
        }
    }

    public func removeUnpermittedVersions(permittedIds: Set<Int>) {
        let downloads = Self.downloadedVersions
        for downloadedId in downloads where !permittedIds.contains(downloadedId) {
            print("Removing downloaded Bible version \(downloadedId) because it is no longer permitted")
            removeVersion(withId: downloadedId)
        }
    }

    public static var downloadedVersions: [Int] {
        guard let downloadsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return []
        }
        return scanForVersionsIn(dir: downloadsDirectory)
    }

}

public actor BibleVersionRepository: Observable {

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
            print("BibleVersionRepository.version: \(error)")
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
