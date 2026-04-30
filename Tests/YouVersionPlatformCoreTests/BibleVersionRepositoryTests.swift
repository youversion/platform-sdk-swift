import Foundation
import Testing
@testable import YouVersionPlatformCore

// MARK: - API Request Counter

final class BibleVersionAPIRequestCounter: BibleVersionProviding, @unchecked Sendable {
    private(set) var requestedIds: [Int] = []
    var result: BibleVersion
    var error: Error?

    init(result: BibleVersion, error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func version(withId id: Int) async throws -> BibleVersion {
        requestedIds.append(id)
        if let error {
            throw error
        }
        return result
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
        let diskCache = VersionDiskCache(directoryProvider: storage.provider)
        await diskCache.addVersion(Self.fixture)

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
        let downloadCache = VersionDownloadCache(directoryProvider: storage.provider)
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
        let diskCache = VersionDiskCache(directoryProvider: storage.provider)

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
        let diskCache = VersionDiskCache(directoryProvider: storage.provider)

        let first = try await repository.version(withId: Self.fixture.id)
        await diskCache.removeVersion(withId: Self.fixture.id)
        let second = try await repository.version(withId: Self.fixture.id)

        #expect(first.id == Self.fixture.id)
        #expect(second.id == Self.fixture.id)
        #expect(second.readerFooter == Self.fixture.readerFooter)
        #expect(api.callCount == 1)
    }

    @Test
    func versionRefetchesAfterCachesAreCleared() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = VersionDiskCache(directoryProvider: storage.provider)

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
        let downloadCache = VersionDownloadCache(directoryProvider: storage.provider)
        await downloadCache.addVersion(Self.fixture)

        try await repository.downloadVersion(withId: Self.fixture.id)

        #expect(api.callCount == 0)
        #expect(await downloadCache.version(withId: Self.fixture.id)?.abbreviation == Self.fixture.abbreviation)
    }

    @Test
    func downloadVersionFetchesWhenNotDownloaded() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = VersionDiskCache(directoryProvider: storage.provider)
        let downloadCache = VersionDownloadCache(directoryProvider: storage.provider)

        try await repository.downloadVersion(withId: Self.fixture.id)

        #expect(api.callCount == 1)
        #expect(await downloadCache.version(withId: Self.fixture.id)?.promotionalContent == Self.fixture.promotionalContent)
        #expect(await diskCache.version(withId: Self.fixture.id) == nil)
    }

    // MARK: Other methods

    @Test
    func diskCacheVersionIsPresentReflectsStoredMetadata() async throws {
        let storage = try RepositoryTemporaryStorage()
        defer { storage.remove() }
        let diskCache = VersionDiskCache(directoryProvider: storage.provider)

        #expect(diskCache.versionIsPresent(for: Self.fixture.id) == false)

        await diskCache.addVersion(Self.fixture)

        #expect(diskCache.versionIsPresent(for: Self.fixture.id))
    }

    @Test
    func versionIsPresentReflectsDownloadCache() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let downloadCache = VersionDownloadCache(directoryProvider: storage.provider)

        #expect(await repository.versionIsPresent(for: Self.fixture.id) == false)

        await downloadCache.addVersion(Self.fixture)

        #expect(await repository.versionIsPresent(for: Self.fixture.id))
        #expect(api.callCount == 0)
    }

    @Test
    func downloadStatusReflectsDownloadCache() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let downloadCache = VersionDownloadCache(directoryProvider: storage.provider)

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
        let downloadCache = VersionDownloadCache(directoryProvider: storage.provider)

        #expect(repository.downloadedVersionIds == [])

        await downloadCache.addVersion(Self.fixture)

        #expect(repository.downloadedVersionIds == [Self.fixture.id])
        #expect(api.callCount == 0)
    }

    @Test
    func removeVersionClearsAllCaches() async throws {
        let (repository, api, storage) = try makeRepository()
        defer { storage.remove() }
        let diskCache = VersionDiskCache(directoryProvider: storage.provider)
        let downloadCache = VersionDownloadCache(directoryProvider: storage.provider)

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
        let diskCache = VersionDiskCache(directoryProvider: storage.provider)
        let downloadCache = VersionDownloadCache(directoryProvider: storage.provider)

        _ = try await repository.version(withId: Self.fixture.id)
        await downloadCache.addVersion(Self.fixture)

        await repository.removeUnpermittedVersions(permittedIds: [])

        #expect(await diskCache.version(withId: Self.fixture.id) == nil)
        #expect(await downloadCache.version(withId: Self.fixture.id) == nil)

        _ = try await repository.version(withId: Self.fixture.id)
        #expect(api.callCount == 2)
    }
}
