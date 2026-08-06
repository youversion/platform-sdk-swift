import Foundation

enum BibleContentStorageKind: Sendable {
    case cache
    case download
}

protocol BibleContentDirectoryProviding: Sendable {
    func rootURL(for storageKind: BibleContentStorageKind) -> URL
}

struct DefaultBibleContentDirectoryProvider: BibleContentDirectoryProviding {
    func rootURL(for storageKind: BibleContentStorageKind) -> URL {
        let searchPathDirectory: FileManager.SearchPathDirectory = switch storageKind {
        case .cache:
            .cachesDirectory
        case .download:
            .applicationSupportDirectory
        }

        return FileManager.default.urls(for: searchPathDirectory, in: .userDomainMask).first!
    }
}

enum BibleContentStorageResource: Sendable {
    case versionDirectory(versionId: Int)
    case versionMetadata(versionId: Int)
    case versionMetadataExpiration(versionId: Int)
    case chaptersDirectory(versionId: Int)
    case chapter(versionId: Int, chapterPassageId: String)
    case chapterExpiration(versionId: Int, chapterPassageId: String)
}

private struct BibleContentCacheExpiration: Codable {
    let expirationDate: Date
}

private enum BibleContentStoragePath {
    static let versionDirectoryPrefix = "bible_"
    static let versionMetadataFileName = "BibleVersionMetadata_v1"
    static let chaptersDirectoryName = "Chapters"
    static let expirationFileExtension = "expiration"
}

actor BibleContentCacheCoordinator {
    static let shared = BibleContentCacheCoordinator()

    func perform<Value: Sendable>(_ operation: @Sendable () throws -> Value) rethrows -> Value {
        try operation()
    }
}

struct BibleContentStorage: Sendable {
    private let storageKind: BibleContentStorageKind
    private let directoryProvider: BibleContentDirectoryProviding

    init(
        storageKind: BibleContentStorageKind,
        directoryProvider: BibleContentDirectoryProviding = DefaultBibleContentDirectoryProvider()
    ) {
        self.storageKind = storageKind
        self.directoryProvider = directoryProvider
    }

    var versionDirectoryIds: [Int] {
        let dir = directoryProvider.rootURL(for: storageKind)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var ids: [Int] = []
        let prefix = BibleContentStoragePath.versionDirectoryPrefix

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

    func url(for resource: BibleContentStorageResource) -> URL {
        switch resource {
        case let .versionDirectory(versionId):
            directoryProvider.rootURL(for: storageKind)
                .appending(
                    path: BibleContentStoragePath.versionDirectoryPrefix + String(versionId),
                    directoryHint: .isDirectory
                )
        case let .versionMetadata(versionId):
            url(for: .versionDirectory(versionId: versionId))
                .appending(
                    path: BibleContentStoragePath.versionMetadataFileName,
                    directoryHint: .notDirectory
                )
        case let .versionMetadataExpiration(versionId):
            url(for: .versionMetadata(versionId: versionId))
                .appendingPathExtension(BibleContentStoragePath.expirationFileExtension)
        case let .chaptersDirectory(versionId):
            url(for: .versionDirectory(versionId: versionId))
                .appending(path: BibleContentStoragePath.chaptersDirectoryName, directoryHint: .isDirectory)
        case let .chapter(versionId, chapterPassageId):
            url(for: .chaptersDirectory(versionId: versionId))
                .appending(path: chapterPassageId, directoryHint: .notDirectory)
        case let .chapterExpiration(versionId, chapterPassageId):
            url(for: .chapter(versionId: versionId, chapterPassageId: chapterPassageId))
                .appendingPathExtension(BibleContentStoragePath.expirationFileExtension)
        }
    }

    func data(for resource: BibleContentStorageResource) -> Data? {
        try? Data(contentsOf: url(for: resource))
    }

    func string(for resource: BibleContentStorageResource) -> String? {
        guard let data = data(for: resource) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func decoded<T: Decodable>(_ type: T.Type, for resource: BibleContentStorageResource) -> T? {
        guard let data = data(for: resource) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    func write(_ data: Data, to resource: BibleContentStorageResource, isExcludedFromBackup: Bool = false) throws {
        var directoryURL = url(for: resource).deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        if isExcludedFromBackup {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? directoryURL.setResourceValues(values)
        }

        try data.write(to: url(for: resource), options: .atomic)
    }

    func writeString(_ string: String, to resource: BibleContentStorageResource) throws {
        try write(Data(string.utf8), to: resource)
    }

    func writeEncoded<T: Encodable>(
        _ value: T,
        to resource: BibleContentStorageResource,
        isExcludedFromBackup: Bool = false
    ) throws {
        try write(JSONEncoder().encode(value), to: resource, isExcludedFromBackup: isExcludedFromBackup)
    }

    func expirationDate(for resource: BibleContentStorageResource) -> Date? {
        cacheExpiration(for: resource)?.expirationDate
    }

    func isExpired(_ resource: BibleContentStorageResource, currentDate: Date) -> Bool {
        let expirationMetadataResource = expirationResource(for: resource)
        guard hasResource(expirationMetadataResource) else {
            return true
        }
        guard let cacheExpiration = decoded(
            BibleContentCacheExpiration.self,
            for: expirationMetadataResource
        ) else {
            return true
        }
        return cacheExpiration.expirationDate <= currentDate
    }

    func writeExpirationDate(_ expirationDate: Date, for resource: BibleContentStorageResource) throws {
        try writeEncoded(
            BibleContentCacheExpiration(expirationDate: expirationDate),
            to: expirationResource(for: resource)
        )
    }

    func removeCacheEntry(_ contentResource: BibleContentStorageResource) {
        removeCacheEntry(at: url(for: contentResource))
    }

    func removeExpiredCachedResources(currentDate: Date) {
        guard storageKind == .cache,
              let enumerator = FileManager.default.enumerator(
                at: directoryProvider.rootURL(for: storageKind),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return
        }

        let urls = enumerator.compactMap { $0 as? URL }
        let expirationURLs = urls.filter {
            $0.pathExtension == BibleContentStoragePath.expirationFileExtension
        }
        for expirationURL in expirationURLs {
            guard let cacheExpiration = data(at: expirationURL).flatMap({
                try? JSONDecoder().decode(BibleContentCacheExpiration.self, from: $0)
            }) else {
                removeCacheEntry(at: expirationURL.deletingPathExtension())
                continue
            }
            guard cacheExpiration.expirationDate <= currentDate else {
                continue
            }
            removeCacheEntry(at: expirationURL.deletingPathExtension())
        }

        let contentURLs = urls.filter { url in
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return false
            }
            return url.lastPathComponent == BibleContentStoragePath.versionMetadataFileName
                || (url.pathComponents.contains(BibleContentStoragePath.chaptersDirectoryName)
                    && url.pathExtension != BibleContentStoragePath.expirationFileExtension)
        }
        for contentURL in contentURLs where !FileManager.default.fileExists(
            atPath: contentURL.appendingPathExtension(BibleContentStoragePath.expirationFileExtension).path
        ) {
            removeCacheEntry(at: contentURL)
        }
    }

    func hasResource(_ resource: BibleContentStorageResource) -> Bool {
        FileManager.default.fileExists(atPath: url(for: resource).path)
    }

    func containsNonEmptyDirectory(_ resource: BibleContentStorageResource) -> Bool {
        let path = url(for: resource).path()
        guard let contents = FileManager.default.subpaths(atPath: path) else {
            return false
        }
        return !contents.isEmpty
    }

    func remove(_ resource: BibleContentStorageResource) throws {
        try removeItem(at: url(for: resource))
    }

    private func expirationResource(for resource: BibleContentStorageResource) -> BibleContentStorageResource {
        switch resource {
        case let .versionMetadata(versionId):
            .versionMetadataExpiration(versionId: versionId)
        case let .chapter(versionId, chapterPassageId):
            .chapterExpiration(versionId: versionId, chapterPassageId: chapterPassageId)
        case .versionDirectory, .chaptersDirectory, .versionMetadataExpiration, .chapterExpiration:
            resource
        }
    }

    private func cacheExpiration(for resource: BibleContentStorageResource) -> BibleContentCacheExpiration? {
        decoded(BibleContentCacheExpiration.self, for: expirationResource(for: resource))
    }

    private func data(at url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    private func removeCacheEntry(at contentURL: URL) {
        try? removeItem(at: contentURL)
        try? removeItem(
            at: contentURL.appendingPathExtension(BibleContentStoragePath.expirationFileExtension)
        )
    }

    private func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
