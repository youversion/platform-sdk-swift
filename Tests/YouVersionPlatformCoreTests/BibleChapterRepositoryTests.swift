import Foundation
import Testing
@testable import YouVersionPlatformCore

// MARK: - API Request Counter

final class BibleChapterAPIRequestCounter: BibleChapterContentProviding, @unchecked Sendable {
    private(set) var requestedReferences: [BibleReference] = []
    var result: String
    var expirationDate: Date?
    var isCacheable: Bool
    var error: Error?

    init(
        result: String,
        expirationDate: Date? = .distantFuture,
        isCacheable: Bool = true,
        error: Error? = nil
    ) {
        self.result = result
        self.expirationDate = expirationDate
        self.isCacheable = isCacheable
        self.error = error
    }

    func chapterContent(for reference: BibleReference) async throws -> CachedBibleContent<String> {
        requestedReferences.append(reference)
        if let error {
            throw error
        }
        return CachedBibleContent(
            value: result,
            expirationDate: expirationDate,
            isCacheable: isCacheable
        )
    }

    var callCount: Int { requestedReferences.count }
}

// MARK: - Tests

struct BibleChapterRepositoryTests {
    private let reference = BibleReference(versionId: 206, bookId: "GEN", chapter: 1)

    @discardableResult
    private func makeRepository(
        apiCounter: BibleChapterAPIRequestCounter? = nil
    ) throws -> (
        repository: BibleChapterRepository,
        apiCounter: BibleChapterAPIRequestCounter,
        storage: RepositoryTemporaryStorage
    ) {
        let apiCounter = apiCounter ?? BibleChapterAPIRequestCounter(result: "<div>server</div>")
        let storage = try RepositoryTemporaryStorage()

        return (
            BibleChapterRepository(
                provider: apiCounter,
                directoryProvider: storage.provider
            ),
            apiCounter,
            storage
        )
    }

    @Test
    func chapterReturnsDiskContentAndWarmsMemory() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleChapterDiskCache(directoryProvider: storage.provider)
        await diskCache.addChapterContent(
            "<div>disk</div>",
            reference: reference,
            expirationDate: .distantFuture
        )

        let content = try await repository.chapter(withReference: reference)
        await diskCache.removeVersion(withId: reference.versionId)
        let memoryContent = try await repository.chapter(withReference: reference)

        #expect(content == "<div>disk</div>")
        #expect(memoryContent == "<div>disk</div>")
        #expect(api.callCount == 0)
    }

    @Test
    func chapterReturnsDownloadContentAndWarmsMemory() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        try writeDownloadedChapterContent("<div>download</div>", reference: reference, storage: storage)

        let content = try await repository.chapter(withReference: reference)
        try FileManager.default.removeItem(at: chapterURL(storageKind: .download, reference: reference, storage: storage))
        let memoryContent = try await repository.chapter(withReference: reference)

        #expect(content == "<div>download</div>")
        #expect(memoryContent == "<div>download</div>")
        #expect(api.callCount == 0)
    }

    @Test
    func chapterLoadsFromAPIWhenNotCachedAndStoresOnDisk() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleChapterDiskCache(directoryProvider: storage.provider)

        let content = try await repository.chapter(withReference: reference)
        let diskContent = await diskCache.chapterContent(withReference: reference)

        #expect(content == "<div>server</div>")
        #expect(api.callCount == 1)
        #expect(api.requestedReferences == [reference])
        #expect(diskContent == "<div>server</div>")
    }

    @Test
    func chapterUsesMemoryCacheOnSubsequentCalls() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleChapterDiskCache(directoryProvider: storage.provider)

        let first = try await repository.chapter(withReference: reference)
        await diskCache.removeVersion(withId: reference.versionId)
        let second = try await repository.chapter(withReference: reference)

        #expect(first == "<div>server</div>")
        #expect(second == "<div>server</div>")
        #expect(api.callCount == 1)
    }

    @Test
    func chapterCachesResponseWithoutExpirationForDefaultDuration() async throws {
        let currentDate = Date(timeIntervalSince1970: 1_000)
        let api = BibleChapterAPIRequestCounter(
            result: "<div>first</div>",
            expirationDate: nil
        )
        let (repository, _, storage) = try makeRepository(apiCounter: api)
        defer { storage.remove() }
        let diskCache = BibleChapterDiskCache(directoryProvider: storage.provider)

        let first = try await repository.chapter(withReference: reference, currentDate: currentDate)
        api.result = "<div>second</div>"
        let second = try await repository.chapter(
            withReference: reference,
            currentDate: currentDate.addingTimeInterval(BibleContentCachePolicy.defaultDuration - 1)
        )

        #expect(first == "<div>first</div>")
        #expect(second == "<div>first</div>")
        #expect(api.callCount == 1)
        #expect(
            await diskCache.chapterContent(withReference: reference, currentDate: currentDate)
                == "<div>first</div>"
        )
    }

    @Test
    func chapterCachesResponseThatForbidsPersistentCachingInMemoryOnly() async throws {
        let api = BibleChapterAPIRequestCounter(
            result: "<div>first</div>",
            expirationDate: .distantFuture,
            isCacheable: false
        )
        let (repository, _, storage) = try makeRepository(apiCounter: api)
        defer { storage.remove() }
        let diskCache = BibleChapterDiskCache(directoryProvider: storage.provider)

        let first = try await repository.chapter(withReference: reference)
        api.result = "<div>second</div>"
        let second = try await repository.chapter(withReference: reference)

        #expect(first == "<div>first</div>")
        #expect(second == "<div>first</div>")
        #expect(api.callCount == 1)
        #expect(await diskCache.chapterContent(withReference: reference) == nil)
    }

    @Test
    func chapterRefetchesAfterCachedResponseExpires() async throws {
        let initialDate = Date(timeIntervalSince1970: 1_000)
        let expiredDate = initialDate.addingTimeInterval(61)
        let api = BibleChapterAPIRequestCounter(
            result: "<div>first</div>",
            expirationDate: initialDate.addingTimeInterval(60)
        )
        let (repository, _, storage) = try makeRepository(apiCounter: api)
        defer { storage.remove() }

        let first = try await repository.chapter(withReference: reference, currentDate: initialDate)
        api.result = "<div>second</div>"
        api.expirationDate = expiredDate.addingTimeInterval(120)
        let second = try await repository.chapter(withReference: reference, currentDate: expiredDate)

        #expect(first == "<div>first</div>")
        #expect(second == "<div>second</div>")
        #expect(api.callCount == 2)
    }

    @Test
    func chapterPropagatesAPIErrorAndDoesNotCache() async throws {
        let api = BibleChapterAPIRequestCounter(result: "<div>server</div>", error: TestChapterError.network)
        let (repository, _, storage) = try makeRepository(apiCounter: api)
        defer { storage.remove() }
        let diskCache = BibleChapterDiskCache(directoryProvider: storage.provider)

        await #expect(throws: TestChapterError.network) {
            _ = try await repository.chapter(withReference: reference)
        }

        #expect(api.callCount == 1)
        #expect(await diskCache.chapterContent(withReference: reference) == nil)
    }

    @Test
    func chaptersArePresentReflectsDownloadedChapters() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }

        #expect(await repository.chaptersArePresent(versionId: reference.versionId) == false)

        try writeDownloadedChapterContent("<div>download</div>", reference: reference, storage: storage)

        #expect(await repository.chaptersArePresent(versionId: reference.versionId))
        #expect(api.callCount == 0)
    }

    @Test
    func removeVersionClearsAllCaches() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleChapterDiskCache(directoryProvider: storage.provider)

        await diskCache.addChapterContent(
            "<div>disk</div>",
            reference: reference,
            expirationDate: .distantFuture
        )
        try writeDownloadedChapterContent("<div>download</div>", reference: reference, storage: storage)

        let diskContent = try await repository.chapter(withReference: reference)
        #expect(diskContent == "<div>disk</div>")

        await repository.removeVersion(withId: reference.versionId)

        #expect(await diskCache.chapterContent(withReference: reference) == nil)
        #expect(FileManager.default.fileExists(atPath: chapterURL(storageKind: .download, reference: reference, storage: storage).path) == false)

        let apiContent = try await repository.chapter(withReference: reference)
        #expect(apiContent == "<div>server</div>")
        #expect(api.callCount == 1)
    }

    private func writeDownloadedChapterContent(
        _ content: String,
        reference: BibleReference,
        storage: RepositoryTemporaryStorage
    ) throws {
        try storage.write(content, to: chapterURL(storageKind: .download, reference: reference, storage: storage))
    }

    private func chapterURL(
        storageKind: BibleContentStorageKind,
        reference: BibleReference,
        storage: RepositoryTemporaryStorage
    ) -> URL {
        let chapterPassageId = reference.chapterPassageId
        return BibleContentStorage(storageKind: storageKind, directoryProvider: storage.provider)
            .url(for: .chapter(versionId: reference.versionId, chapterPassageId: chapterPassageId))
    }
}

private enum TestChapterError: Error {
    case network
}
