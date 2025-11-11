import Foundation
import Testing
@testable import YouVersionPlatformCore

// MARK: - Mocks

final class MockBibleVersionAPIClient: BibleVersionAPIClient, @unchecked Sendable {
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

final class MockBibleVersionCache: BibleVersionCaching, @unchecked Sendable {
    private var storage: [Int: BibleVersion] = [:]
    private(set) var versionCallCount = 0
    private(set) var addCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var removeUnpermittedCallCount = 0
    private(set) var versionIsPresentCallCount = 0

    func version(withId id: Int) async -> BibleVersion? {
        versionCallCount += 1
        return storage[id]
    }

    func addVersion(_ version: BibleVersion) async {
        addCallCount += 1
        storage[version.id] = version
    }

    func removeVersion(withId versionId: Int) async {
        removeCallCount += 1
        storage.removeValue(forKey: versionId)
    }

    func versionIsPresent(for id: Int) -> Bool {
        versionIsPresentCallCount += 1
        return storage[id] != nil
    }

    func removeUnpermittedVersions(permittedIds: Set<Int>) async {
        removeUnpermittedCallCount += 1
        storage = storage.filter { permittedIds.contains($0.key) }
    }

    func prime(with version: BibleVersion) {
        storage[version.id] = version
    }

    func contains(_ id: Int) -> Bool {
        storage[id] != nil
    }

    func storedVersion(withId id: Int) -> BibleVersion? {
        storage[id]
    }
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
        apiClient: MockBibleVersionAPIClient? = nil,
        memoryCache: MockBibleVersionCache? = nil,
        diskCache: MockBibleVersionCache? = nil,
        downloadCache: MockBibleVersionCache? = nil
    ) -> (
        repository: BibleVersionRepository,
        apiClient: MockBibleVersionAPIClient,
        memoryCache: MockBibleVersionCache,
        diskCache: MockBibleVersionCache,
        downloadCache: MockBibleVersionCache
    ) {
        let apiClient = apiClient ?? MockBibleVersionAPIClient(result: Self.fixture)
        let memoryCache = memoryCache ?? MockBibleVersionCache()
        let diskCache = diskCache ?? MockBibleVersionCache()
        let downloadCache = downloadCache ?? MockBibleVersionCache()

        return (
            BibleVersionRepository(
                apiClient: apiClient,
                memoryCache: memoryCache,
                diskCache: diskCache,
                downloadCache: downloadCache
            ),
            apiClient,
            memoryCache,
            diskCache,
            downloadCache
        )
    }

    // MARK: versionIfCached

    @Test
    func versionIfCachedReturnsDiskVersionAndWarmsMemory() async throws {
        let (repository, api, memory, disk, _) = makeRepository()
        disk.prime(with: Self.fixture)

        let cached = try await repository.versionIfCached(Self.fixture.id)

        #expect(cached?.id == Self.fixture.id)
        #expect(cached?.localizedTitle == Self.fixture.localizedTitle)
        #expect(api.callCount == 0)
        #expect(memory.contains(Self.fixture.id))
        #expect(memory.addCallCount == 1)
        #expect(disk.versionCallCount == 1)
    }

    // MARK: version(withId:)

    @Test
    func versionLoadsFromAPIWhenNotCachedAndStoresInCaches() async throws {
        let (repository, api, memory, disk, _) = makeRepository()

        let version = try await repository.version(withId: Self.fixture.id)

        #expect(version.id == Self.fixture.id)
        #expect(version.languageTag == Self.fixture.languageTag)
        #expect(version.title == Self.fixture.title)
        #expect(api.callCount == 1)
        #expect(memory.contains(Self.fixture.id))
        #expect(memory.addCallCount == 1)
        #expect(disk.contains(Self.fixture.id))
        #expect(disk.addCallCount >= 1)
        #expect(disk.storedVersion(withId: Self.fixture.id)?.copyrightShort == Self.fixture.copyrightShort)
    }

    @Test
    func versionUsesMemoryCacheOnSubsequentCalls() async throws {
        let (repository, api, memory, _, _) = makeRepository()

        let first = try await repository.version(withId: Self.fixture.id)
        let second = try await repository.version(withId: Self.fixture.id)

        #expect(first.id == Self.fixture.id)
        #expect(first.localizedAbbreviation == Self.fixture.localizedAbbreviation)
        #expect(second.id == Self.fixture.id)
        #expect(second.readerFooter == Self.fixture.readerFooter)
        #expect(api.callCount == 1)
        #expect(memory.versionCallCount >= 2)
    }

    @Test
    func versionRefetchesAfterCachesAreCleared() async throws {
        let (repository, api, memory, disk, _) = makeRepository()

        let initial = try await repository.version(withId: Self.fixture.id)
        #expect(initial.copyrightShort == Self.fixture.copyrightShort)
        #expect(api.callCount == 1)

        await repository.removeVersion(withId: Self.fixture.id)

        #expect(memory.contains(Self.fixture.id) == false)
        #expect(disk.contains(Self.fixture.id) == false)
        #expect(disk.storedVersion(withId: Self.fixture.id) == nil)

        let refetched = try await repository.version(withId: Self.fixture.id)

        #expect(refetched.readerFooterUrl == Self.fixture.readerFooterUrl)
        #expect(api.callCount == 2)
        #expect(memory.contains(Self.fixture.id))
        #expect(disk.contains(Self.fixture.id))
        #expect(disk.storedVersion(withId: Self.fixture.id)?.title == Self.fixture.title)
    }

    // MARK: downloadVersion

    @Test
    func downloadVersionDoesNotFetchWhenAlreadyDownloaded() async throws {
        let (repository, api, _, disk, download) = makeRepository()
        download.prime(with: Self.fixture)

        try await repository.downloadVersion(withId: Self.fixture.id)

        #expect(api.callCount == 0)
        #expect(download.addCallCount == 0)
        #expect(disk.removeCallCount == 0)

        let stored = download.storedVersion(withId: Self.fixture.id)
        #expect(stored?.abbreviation == Self.fixture.abbreviation)
    }

    @Test
    func downloadVersionFetchesWhenNotDownloaded() async throws {
        let (repository, api, _, disk, download) = makeRepository()

        try await repository.downloadVersion(withId: Self.fixture.id)

        #expect(api.callCount == 1)
        #expect(download.contains(Self.fixture.id))
        #expect(download.addCallCount == 1)
        #expect(disk.removeCallCount == 1)

        let stored = download.storedVersion(withId: Self.fixture.id)
        #expect(stored?.copyrightLong == Self.fixture.copyrightLong)
    }

    // MARK: Other methods

    @Test
    func versionIsPresentDelegatesToDownloadCache() async throws {
        let (repository, api, _, _, download) = makeRepository()
        download.prime(with: Self.fixture)

        let isPresent = await repository.versionIsPresent(for: Self.fixture.id)

        #expect(isPresent)
        #expect(download.versionIsPresentCallCount == 1)
        #expect(api.callCount == 0)
    }

    @Test
    func downloadStatusReflectsDownloadCache() async throws {
        let (repository, api, _, _, download) = makeRepository()
        download.prime(with: Self.fixture)

        let status = repository.downloadStatus(for: Self.fixture.id)
        let otherStatus = repository.downloadStatus(for: 999)

        #expect(status == .downloaded)
        #expect(otherStatus == .notDownloadable)
        #expect(api.callCount == 0)
    }

    @Test
    func removeVersionClearsAllCaches() async throws {
        let (repository, _, memory, disk, download) = makeRepository()
        memory.prime(with: Self.fixture)
        disk.prime(with: Self.fixture)
        download.prime(with: Self.fixture)

        await repository.removeVersion(withId: Self.fixture.id)

        #expect(memory.removeCallCount == 1)
        #expect(disk.removeCallCount == 1)
        #expect(download.removeCallCount == 1)
    }

    @Test
    func removeUnpermittedVersionsForwardsToCaches() async throws {
        let (repository, _, memory, disk, download) = makeRepository()

        await repository.removeUnpermittedVersions(permittedIds: [])

        #expect(memory.removeUnpermittedCallCount == 1)
        #expect(disk.removeUnpermittedCallCount == 1)
        #expect(download.removeUnpermittedCallCount == 1)
    }
}
