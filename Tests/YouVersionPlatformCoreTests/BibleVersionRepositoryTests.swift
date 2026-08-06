import Foundation
import Testing
@testable import YouVersionPlatformCore

// MARK: - API Request Counter

final class BibleVersionAPIRequestCounter: BibleVersionProviding, @unchecked Sendable {
    private(set) var requestedIds: [Int] = []
    var result: BibleVersion
    var expirationDate: Date?
    var isCacheable: Bool
    var error: Error?

    init(
        result: BibleVersion,
        expirationDate: Date? = .distantFuture,
        isCacheable: Bool = true,
        error: Error? = nil
    ) {
        self.result = result
        self.expirationDate = expirationDate
        self.isCacheable = isCacheable
        self.error = error
    }

    func version(withId id: Int) async throws -> CachedBibleContent<BibleVersion> {
        requestedIds.append(id)
        if let error {
            throw error
        }
        return CachedBibleContent(
            value: result,
            expirationDate: expirationDate,
            isCacheable: isCacheable
        )
    }

    var callCount: Int { requestedIds.count }
}

// MARK: - Tests

struct BibleVersionRepositoryTests {

    private static let fixture: BibleVersion = {
        guard let url = Bundle.module.url(forResource: "bible_206", withExtension: "json") else {
            fatalError("Missing bible_206.json fixture in test bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BibleVersion.self, from: data)
        } catch {
            fatalError("Failed to decode bible_206.json: \(error)")
        }
    }()

    @discardableResult
    private func makeRepository(
        apiRequestCounter: BibleVersionAPIRequestCounter? = nil
    ) throws -> (
        repository: BibleVersionRepository,
        apiRequestCounter: BibleVersionAPIRequestCounter,
        storage: RepositoryTemporaryStorage
    ) {
        let apiRequestCounter = apiRequestCounter ?? BibleVersionAPIRequestCounter(result: Self.fixture)
        let storage = try RepositoryTemporaryStorage()

        return (
            BibleVersionRepository(
                provider: apiRequestCounter,
                directoryProvider: storage.provider
            ),
            apiRequestCounter,
            storage
        )
    }

    // MARK: versionIfCached

    @Test
    func versionIfCachedReturnsDiskVersionAndWarmsMemory() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)
        await diskCache.addVersion(Self.fixture, expirationDate: .distantFuture)

        let cached = try await repository.versionIfCached(Self.fixture.id)
        await diskCache.removeVersion(withId: Self.fixture.id)
        let memoryCached = try await repository.versionIfCached(Self.fixture.id)

        #expect(cached?.id == Self.fixture.id)
        #expect(memoryCached?.id == Self.fixture.id)
        #expect(memoryCached?.localizedTitle == Self.fixture.localizedTitle)
        #expect(api.callCount == 0)
    }

    @Test
    func versionIfCachedReturnsDownloadVersionAndWarmsMemory() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let downloadCache = BibleVersionDownloadCache(directoryProvider: storage.provider)
        await downloadCache.addVersion(Self.fixture)

        let cached = try await repository.versionIfCached(Self.fixture.id)
        await downloadCache.removeVersion(withId: Self.fixture.id)
        let memoryCached = try await repository.versionIfCached(Self.fixture.id)

        #expect(cached?.id == Self.fixture.id)
        #expect(memoryCached?.id == Self.fixture.id)
        #expect(memoryCached?.abbreviation == Self.fixture.abbreviation)
        #expect(api.callCount == 0)
    }

    // MARK: version(withId:)

    @Test
    func versionLoadsFromAPIWhenNotCachedAndStoresOnDisk() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)

        let version = try await repository.version(withId: Self.fixture.id)
        let diskVersion = await diskCache.version(withId: Self.fixture.id)

        #expect(version.id == Self.fixture.id)
        #expect(version.languageTag == Self.fixture.languageTag)
        #expect(api.callCount == 1)
        #expect(api.requestedIds == [Self.fixture.id])
        #expect(diskVersion?.id == Self.fixture.id)
        #expect(diskVersion?.copyright == Self.fixture.copyright)
    }

    @Test
    func versionUsesMemoryCacheOnSubsequentCalls() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)

        let first = try await repository.version(withId: Self.fixture.id)
        await diskCache.removeVersion(withId: Self.fixture.id)
        let second = try await repository.version(withId: Self.fixture.id)

        #expect(first.id == Self.fixture.id)
        #expect(second.id == Self.fixture.id)
        #expect(second.readerFooter == Self.fixture.readerFooter)
        #expect(api.callCount == 1)
    }

    @Test
    func versionCachesResponseWithoutExpirationForDefaultDuration() async throws {
        let currentDate = Date(timeIntervalSince1970: 1_000)
        let api = BibleVersionAPIRequestCounter(
            result: Self.fixture,
            expirationDate: nil
        )
        let (repository, _, storage) = try makeRepository(apiRequestCounter: api)
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)

        _ = try await repository.version(withId: Self.fixture.id, currentDate: currentDate)
        _ = try await repository.version(
            withId: Self.fixture.id,
            currentDate: currentDate.addingTimeInterval(BibleContentCachePolicy.defaultDuration - 1)
        )

        #expect(api.callCount == 1)
        #expect(await diskCache.version(withId: Self.fixture.id, currentDate: currentDate)?.id == Self.fixture.id)
    }

    @Test
    func versionDoesNotCacheResponseThatForbidsCaching() async throws {
        let api = BibleVersionAPIRequestCounter(
            result: Self.fixture,
            expirationDate: .distantFuture,
            isCacheable: false
        )
        let (repository, _, storage) = try makeRepository(apiRequestCounter: api)
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)

        _ = try await repository.version(withId: Self.fixture.id)
        _ = try await repository.version(withId: Self.fixture.id)

        #expect(api.callCount == 2)
        #expect(await diskCache.version(withId: Self.fixture.id) == nil)
    }

    @Test
    func versionRefetchesAfterCachedResponseExpires() async throws {
        let initialDate = Date(timeIntervalSince1970: 1_000)
        let expiredDate = initialDate.addingTimeInterval(61)
        let api = BibleVersionAPIRequestCounter(
            result: Self.fixture,
            expirationDate: initialDate.addingTimeInterval(60)
        )
        let (repository, _, storage) = try makeRepository(apiRequestCounter: api)
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)

        _ = try await repository.version(withId: Self.fixture.id, currentDate: initialDate)
        api.expirationDate = expiredDate.addingTimeInterval(60)
        _ = try await repository.version(withId: Self.fixture.id, currentDate: expiredDate)

        #expect(api.callCount == 2)
        #expect(await diskCache.version(withId: Self.fixture.id, currentDate: expiredDate)?.id == Self.fixture.id)
    }

    @Test
    func versionRefetchesAfterCachesAreCleared() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)

        let initial = try await repository.version(withId: Self.fixture.id)
        #expect(initial.copyright == Self.fixture.copyright)
        #expect(api.callCount == 1)

        await repository.removeVersion(withId: Self.fixture.id)
        #expect(await diskCache.version(withId: Self.fixture.id) == nil)

        let refetched = try await repository.version(withId: Self.fixture.id)

        #expect(refetched.readerFooterUrl == Self.fixture.readerFooterUrl)
        #expect(api.callCount == 2)
        #expect(await diskCache.version(withId: Self.fixture.id)?.title == Self.fixture.title)
    }

    // MARK: downloadVersion

    @Test
    func downloadVersionDoesNotFetchWhenAlreadyDownloaded() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let downloadCache = BibleVersionDownloadCache(directoryProvider: storage.provider)
        await downloadCache.addVersion(Self.fixture)

        try await repository.downloadVersion(withId: Self.fixture.id)

        #expect(api.callCount == 0)
        #expect(await downloadCache.version(withId: Self.fixture.id)?.abbreviation == Self.fixture.abbreviation)
    }

    @Test
    func downloadVersionFetchesWhenNotDownloaded() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)
        let downloadCache = BibleVersionDownloadCache(directoryProvider: storage.provider)

        try await repository.downloadVersion(withId: Self.fixture.id)

        #expect(api.callCount == 1)
        #expect(await downloadCache.version(withId: Self.fixture.id)?.promotionalContent == Self.fixture.promotionalContent)
        #expect(await diskCache.version(withId: Self.fixture.id) == nil)
    }

    // MARK: Other methods

    @Test
    func diskCacheContainsVersionReflectsStoredMetadata() async throws {
        let storage = try RepositoryTemporaryStorage()
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)

        #expect(diskCache.containsVersion(withId: Self.fixture.id) == false)

        await diskCache.addVersion(Self.fixture, expirationDate: .distantFuture)

        #expect(diskCache.containsVersion(withId: Self.fixture.id))
    }

    @Test
    func containsVersionReflectsDownloadCache() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let downloadCache = BibleVersionDownloadCache(directoryProvider: storage.provider)

        #expect(await repository.containsVersion(withId: Self.fixture.id) == false)

        await downloadCache.addVersion(Self.fixture)

        #expect(await repository.containsVersion(withId: Self.fixture.id))
        #expect(api.callCount == 0)
    }

    @Test
    func downloadStatusReflectsDownloadCache() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let downloadCache = BibleVersionDownloadCache(directoryProvider: storage.provider)

        #expect(repository.downloadStatus(for: Self.fixture.id) == .notDownloadable)

        await downloadCache.addVersion(Self.fixture)

        let status = repository.downloadStatus(for: Self.fixture.id)
        let otherStatus = repository.downloadStatus(for: 999)

        #expect(status == .downloaded)
        #expect(otherStatus == .notDownloadable)
        #expect(api.callCount == 0)
    }

    @Test
    func downloadedVersionIdsReflectDownloadCache() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let downloadCache = BibleVersionDownloadCache(directoryProvider: storage.provider)

        #expect(repository.downloadedVersionIds == [])

        await downloadCache.addVersion(Self.fixture)

        #expect(repository.downloadedVersionIds == [Self.fixture.id])
        #expect(api.callCount == 0)
    }

    @Test
    func removeVersionClearsAllCaches() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)
        let downloadCache = BibleVersionDownloadCache(directoryProvider: storage.provider)

        _ = try await repository.version(withId: Self.fixture.id)
        await downloadCache.addVersion(Self.fixture)

        await repository.removeVersion(withId: Self.fixture.id)

        #expect(await diskCache.version(withId: Self.fixture.id) == nil)
        #expect(await downloadCache.version(withId: Self.fixture.id) == nil)

        _ = try await repository.version(withId: Self.fixture.id)
        #expect(api.callCount == 2)
    }

    @Test
    func removeUnpermittedVersionsRemovesStoredVersionsAndMemoryCache() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = BibleVersionDiskCache(directoryProvider: storage.provider)
        let downloadCache = BibleVersionDownloadCache(directoryProvider: storage.provider)

        _ = try await repository.version(withId: Self.fixture.id)
        await downloadCache.addVersion(Self.fixture)

        await repository.removeUnpermittedVersions(permittedIds: [])

        #expect(await diskCache.version(withId: Self.fixture.id) == nil)
        #expect(await downloadCache.version(withId: Self.fixture.id) == nil)

        _ = try await repository.version(withId: Self.fixture.id)
        #expect(api.callCount == 2)
    }

    @Test
    func removeUnpermittedVersionsAlsoRemovesExpiredCachedFiles() async throws {
        let currentDate = Date(timeIntervalSince1970: 2_000)
        let (repository, _, storage) = try makeRepository()
        defer { storage.remove() }
        let versionCache = BibleVersionDiskCache(directoryProvider: storage.provider)
        let chapterCache = BibleChapterDiskCache(directoryProvider: storage.provider)
        let reference = BibleReference(versionId: Self.fixture.id, bookId: "GEN", chapter: 1)

        await versionCache.addVersion(Self.fixture, expirationDate: currentDate.addingTimeInterval(-1))
        await chapterCache.addChapterContent(
            "<div>expired</div>",
            reference: reference,
            expirationDate: currentDate.addingTimeInterval(-1)
        )

        await repository.removeUnpermittedVersions(
            permittedIds: [Self.fixture.id],
            currentDate: currentDate
        )

        #expect(await versionCache.version(withId: Self.fixture.id, currentDate: currentDate) == nil)
        #expect(await chapterCache.chapterContent(withReference: reference, currentDate: currentDate) == nil)
    }
}
