import Foundation
import Testing
@testable import YouVersionPlatformCore

struct BibleContentStorageTests {

    @Test
    func urlBuildsExpectedCacheAndDownloadPaths() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let cacheStorage = BibleContentStorage(storageKind: .cache, directoryProvider: temporaryStorage.provider)
        let downloadStorage = BibleContentStorage(storageKind: .download, directoryProvider: temporaryStorage.provider)

        #expect(
            cacheStorage.url(for: .versionDirectory(versionId: 206)) ==
                temporaryStorage.cacheRootURL.appending(path: "bible_206", directoryHint: .isDirectory)
        )
        #expect(
            cacheStorage.url(for: .versionMetadata(versionId: 206)) ==
                temporaryStorage.cacheRootURL
                .appending(path: "bible_206", directoryHint: .isDirectory)
                .appending(path: "BibleVersionMetadata_v1", directoryHint: .notDirectory)
        )
        #expect(
            downloadStorage.url(for: .chapter(versionId: 206, usfm: "GEN.1")) ==
                temporaryStorage.downloadRootURL
                .appending(path: "bible_206", directoryHint: .isDirectory)
                .appending(path: "Chapters", directoryHint: .isDirectory)
                .appending(path: "GEN.1", directoryHint: .notDirectory)
        )
    }

    @Test
    func versionDirectoryIdsReturnsValidBibleDirectoriesOnly() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        try temporaryStorage.createCacheDirectory(named: "bible_1")
        try temporaryStorage.createCacheDirectory(named: "bible_206")
        try temporaryStorage.createCacheDirectory(named: "bible_123456")
        try temporaryStorage.createCacheDirectory(named: "bible_1234567")
        try temporaryStorage.createCacheDirectory(named: "bible_abc")
        try temporaryStorage.createCacheDirectory(named: "not_bible_7")
        try temporaryStorage.writeCacheFile(named: "bible_999", data: Data())

        let storage = BibleContentStorage(storageKind: .cache, directoryProvider: temporaryStorage.provider)

        #expect(Set(storage.versionDirectoryIds) == Set([1, 206, 123456]))
    }

    @Test
    func versionDirectoryIdsKeepsCacheAndDownloadRootsSeparate() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        try temporaryStorage.createCacheDirectory(named: "bible_1")
        try temporaryStorage.createDownloadDirectory(named: "bible_2")

        let cacheStorage = BibleContentStorage(storageKind: .cache, directoryProvider: temporaryStorage.provider)
        let downloadStorage = BibleContentStorage(storageKind: .download, directoryProvider: temporaryStorage.provider)

        #expect(cacheStorage.versionDirectoryIds == [1])
        #expect(downloadStorage.versionDirectoryIds == [2])
    }

    @Test
    func versionDirectoryIdsReturnsEmptyWhenRootIsMissing() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        try FileManager.default.removeItem(at: temporaryStorage.cacheRootURL)
        let storage = BibleContentStorage(storageKind: .cache, directoryProvider: temporaryStorage.provider)

        #expect(storage.versionDirectoryIds.isEmpty)
    }

    @Test
    func dataAndDecodedReadStoredVersionMetadata() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let storage = BibleContentStorage(storageKind: .cache, directoryProvider: temporaryStorage.provider)
        let fixtureData = try Self.fixtureData()
        try temporaryStorage.write(fixtureData, to: storage.url(for: .versionMetadata(versionId: 206)))

        let data = storage.data(for: .versionMetadata(versionId: 206))
        let version = storage.decoded(BibleVersion.self, for: .versionMetadata(versionId: 206))

        #expect(data == fixtureData)
        #expect(version?.id == 206)
        #expect(version?.localizedTitle == "World English Bible, American English Edition, without Strong's Numbers")
    }

    @Test
    func decodedReturnsNilForMissingOrInvalidData() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let storage = BibleContentStorage(storageKind: .cache, directoryProvider: temporaryStorage.provider)
        try temporaryStorage.write(Data("not json".utf8), to: storage.url(for: .versionMetadata(versionId: 999)))

        let missing = storage.decoded(BibleVersion.self, for: .versionMetadata(versionId: 206))
        let invalid = storage.decoded(BibleVersion.self, for: .versionMetadata(versionId: 999))

        #expect(missing == nil)
        #expect(invalid == nil)
    }

    @Test
    func stringReadsUtf8ChapterContent() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let storage = BibleContentStorage(storageKind: .download, directoryProvider: temporaryStorage.provider)
        try temporaryStorage.write(
            Data("<div>In the beginning</div>".utf8),
            to: storage.url(for: .chapter(versionId: 206, usfm: "GEN.1"))
        )

        let content = storage.string(for: .chapter(versionId: 206, usfm: "GEN.1"))

        #expect(content == "<div>In the beginning</div>")
    }

    @Test
    func stringReturnsNilForMissingOrInvalidUtf8Data() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let storage = BibleContentStorage(storageKind: .download, directoryProvider: temporaryStorage.provider)
        try temporaryStorage.write(Data([0xFF, 0xFE]), to: storage.url(for: .chapter(versionId: 206, usfm: "GEN.1")))

        let missing = storage.string(for: .chapter(versionId: 206, usfm: "EXO.1"))
        let invalid = storage.string(for: .chapter(versionId: 206, usfm: "GEN.1"))

        #expect(missing == nil)
        #expect(invalid == nil)
    }

    @Test
    func containsChecksPresenceWithoutDecoding() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let storage = BibleContentStorage(storageKind: .cache, directoryProvider: temporaryStorage.provider)
        try temporaryStorage.write(Data("not json".utf8), to: storage.url(for: .versionMetadata(versionId: 206)))

        #expect(storage.contains(.versionMetadata(versionId: 206)))
        #expect(storage.contains(.versionMetadata(versionId: 999)) == false)
    }

    @Test
    func containsNonEmptyDirectoryChecksDirectoryContents() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let storage = BibleContentStorage(storageKind: .download, directoryProvider: temporaryStorage.provider)
        try FileManager.default.createDirectory(
            at: storage.url(for: .chaptersDirectory(versionId: 206)),
            withIntermediateDirectories: true
        )

        #expect(storage.containsNonEmptyDirectory(.chaptersDirectory(versionId: 206)) == false)
        #expect(storage.containsNonEmptyDirectory(.chaptersDirectory(versionId: 999)) == false)

        try temporaryStorage.write(
            Data("<div>content</div>".utf8),
            to: storage.url(for: .chapter(versionId: 206, usfm: "GEN.1"))
        )

        #expect(storage.containsNonEmptyDirectory(.chaptersDirectory(versionId: 206)))
    }

    @Test
    func writeEncodedCreatesVersionMetadata() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let storage = BibleContentStorage(storageKind: .cache, directoryProvider: temporaryStorage.provider)
        let fixture = try JSONDecoder().decode(BibleVersion.self, from: Self.fixtureData())

        try storage.writeEncoded(fixture, to: .versionMetadata(versionId: fixture.id))

        #expect(storage.decoded(BibleVersion.self, for: .versionMetadata(versionId: fixture.id))?.id == fixture.id)
    }

    @Test
    func writeStringCreatesChapterContent() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let storage = BibleContentStorage(storageKind: .cache, directoryProvider: temporaryStorage.provider)

        try storage.writeString("chapter content", to: .chapter(versionId: 206, usfm: "GEN.1"))

        #expect(storage.string(for: .chapter(versionId: 206, usfm: "GEN.1")) == "chapter content")
    }

    @Test
    func removeDeletesResourceDirectory() throws {
        let temporaryStorage = try TemporaryStorage()
        defer { temporaryStorage.remove() }

        let storage = BibleContentStorage(storageKind: .download, directoryProvider: temporaryStorage.provider)
        try storage.writeString("chapter content", to: .chapter(versionId: 206, usfm: "GEN.1"))

        try storage.remove(.versionDirectory(versionId: 206))

        #expect(storage.contains(.chapter(versionId: 206, usfm: "GEN.1")) == false)
        #expect(storage.contains(.versionDirectory(versionId: 206)) == false)
    }

    private static func fixtureData() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "bible_206", withExtension: "json"))
        return try Data(contentsOf: url)
    }
}

private struct TemporaryStorage {
    let rootURL: URL
    let cacheRootURL: URL
    let downloadRootURL: URL
    let provider: TestBibleContentDirectoryProvider

    init() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: "BibleContentStorageTests-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    func createCacheDirectory(named name: String) throws {
        try FileManager.default.createDirectory(
            at: cacheRootURL.appending(path: name, directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    func createDownloadDirectory(named name: String) throws {
        try FileManager.default.createDirectory(
            at: downloadRootURL.appending(path: name, directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    func writeCacheFile(named name: String, data: Data) throws {
        try write(data, to: cacheRootURL.appending(path: name, directoryHint: .notDirectory))
    }

    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }
}
