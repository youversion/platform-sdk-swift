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
    case chaptersDirectory(versionId: Int)
    case chapter(versionId: Int, usfm: String)
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

    func url(for resource: BibleContentStorageResource) -> URL {
        switch resource {
        case let .versionDirectory(versionId):
            directoryProvider.rootURL(for: storageKind)
                .appending(path: "bible_\(versionId)", directoryHint: .isDirectory)
        case let .versionMetadata(versionId):
            url(for: .versionDirectory(versionId: versionId))
                .appending(path: "BibleVersionMetadata_v1", directoryHint: .notDirectory)
        case let .chaptersDirectory(versionId):
            url(for: .versionDirectory(versionId: versionId))
                .appending(path: "Chapters", directoryHint: .isDirectory)
        case let .chapter(versionId, usfm):
            url(for: .chaptersDirectory(versionId: versionId))
                .appending(path: usfm, directoryHint: .notDirectory)
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

    func contains(_ resource: BibleContentStorageResource) -> Bool {
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
        try FileManager.default.removeItem(at: url(for: resource))
    }
}
