import Foundation
@testable import YouVersionPlatformCore

struct RepositoryTemporaryStorage {
    let rootURL: URL
    let cacheRootURL: URL
    let downloadRootURL: URL
    let provider: TestBibleContentDirectoryProvider

    init() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: "BibleRepositoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let cacheRootURL = rootURL.appending(path: "cache", directoryHint: .isDirectory)
        let downloadRootURL = rootURL.appending(path: "download", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: cacheRootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloadRootURL, withIntermediateDirectories: true)

        self.rootURL = rootURL
        self.cacheRootURL = cacheRootURL
        self.downloadRootURL = downloadRootURL
        self.provider = TestBibleContentDirectoryProvider(
            cacheRootURL: cacheRootURL,
            downloadRootURL: downloadRootURL
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }

    func write(_ content: String, to url: URL) throws {
        try write(Data(content.utf8), to: url)
    }
}

struct TestBibleContentDirectoryProvider: BibleContentDirectoryProviding {
    let cacheRootURL: URL
    let downloadRootURL: URL

    func rootURL(for storageKind: BibleContentStorageKind) -> URL {
        switch storageKind {
        case .cache:
            cacheRootURL
        case .download:
            downloadRootURL
        }
    }
}
