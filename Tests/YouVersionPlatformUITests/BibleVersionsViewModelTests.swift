import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

private actor MockBibleVersionRepository: BibleVersionRepositoryProtocol {
    var versionById: [Int: BibleVersion] = [:]
    var cachedVersionById: [Int: BibleVersion] = [:]
    var thrownError: Error?
    var downloadedIds: [Int] = []

    init() {}

    func setVersion(_ version: BibleVersion) {
        versionById[version.id] = version
    }

    func setCachedVersion(_ version: BibleVersion) {
        cachedVersionById[version.id] = version
    }

    func setThrownError(_ error: Error?) {
        thrownError = error
    }

    func versionIfCached(_ id: Int) async throws -> BibleVersion? {
        if let thrownError {
            throw thrownError
        }
        return cachedVersionById[id]
    }

    func version(withId id: Int) async throws -> BibleVersion {
        if let thrownError {
            throw thrownError
        }
        if let version = versionById[id] {
            return version
        }
        throw NSError(domain: "BibleVersionsViewModelTests", code: id)
    }

    func downloadVersion(withId id: Int) async throws {
        if let thrownError {
            throw thrownError
        }
        downloadedIds.append(id)
    }

    nonisolated func downloadStatus(for id: Int) -> BibleVersionRepository.BibleVersionDownloadStatus {
        .notDownloadable
    }

    func removeVersion(withId id: Int) async {
    }

    func removeUnpermittedVersions(permittedIds: Set<Int>) async {
    }
}

@MainActor
private final class TestGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func open() {
        isOpen = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
}

@MainActor
@Suite(.serialized) struct BibleVersionsViewModelTests {
    @Test
    func initUsesSharedRepositoryByDefault() {
        let viewModel = BibleVersionsViewModel()

        #expect(viewModel.versionRepository is BibleVersionRepository)
    }

    @available(*, deprecated, message: "Exercises the deprecated callback initializer for backwards compatibility.")
    @Test
    func deprecatedOnVersionChangeCallbackIsInvokedWhenVersionChanges() async {
        let repository = MockBibleVersionRepository()
        let version = makeBibleVersion(id: 111)
        await repository.setVersion(version)
        var changedVersion: BibleVersion?
        let viewModel = BibleVersionsViewModel(
            onVersionChange: { changedVersion = $0 },
            versionRepository: repository
        )

        await viewModel.switchToVersion(version.id)

        #expect(changedVersion == version)
    }

    @Test
    func switchToVersionUsesInjectedRepository() async {
        let repository = MockBibleVersionRepository()
        let version = makeBibleVersion(id: 112)
        await repository.setVersion(version)
        let viewModel = BibleVersionsViewModel(versionRepository: repository)

        await viewModel.switchToVersion(version.id)

        #expect(viewModel.currentVersion == version)
        #expect(viewModel.showGenericAlert == false)
    }

    @Test
    func switchToVersionShowsAlertWhenRepositoryThrows() async {
        let repository = MockBibleVersionRepository()
        await repository.setThrownError(NSError(domain: "BibleVersionsViewModelTests", code: 99))
        let viewModel = BibleVersionsViewModel(versionRepository: repository)

        await viewModel.switchToVersion(111)

        #expect(viewModel.showGenericAlert)
        #expect(viewModel.textForGenericAlertTitle == .localized("generic.error"))
        #expect(viewModel.textForGenericAlertBody == .localized("reader.versionAccessErrorBody"))
    }

    @Test
    func statisticsPromoReadsDoNotLoadPermittedVersions() async {
        let viewModel = BibleVersionsViewModel()
        var loadCount = 0

        #expect(viewModel.bibleVersionStatisticsPromo.isEmpty)
        #expect(viewModel.bibleVersionStatisticsPromo.isEmpty)
        await Task.yield()
        _ = await viewModel.permittedVersions {
            loadCount += 1
            return []
        }

        #expect(loadCount == 1)
    }

    @Test
    func permittedVersionsDoesNotRetryAfterFailure() async {
        let viewModel = BibleVersionsViewModel()
        var loadCount = 0

        func unavailableVersions() async throws -> [YouVersionAPI.Bible.BibleVersionMinimalInfo] {
            loadCount += 1
            throw URLError(.notConnectedToInternet)
        }

        let firstResult = await viewModel.permittedVersions(using: unavailableVersions)
        let secondResult = await viewModel.permittedVersions(using: unavailableVersions)

        #expect(firstResult == nil)
        #expect(secondResult == nil)
        #expect(loadCount == 1)
    }

    @Test
    func permittedVersionsAllowsOneConcurrentAttemptAndCachesEmptySuccess() async {
        let viewModel = BibleVersionsViewModel()
        let loadStarted = TestGate()
        let loadCanFinish = TestGate()
        var loadCount = 0

        let firstLoad = Task {
            await viewModel.permittedVersions {
                loadCount += 1
                loadStarted.open()
                await loadCanFinish.wait()
                return []
            }
        }
        await loadStarted.wait()

        let concurrentResult = await viewModel.permittedVersions {
            loadCount += 1
            return []
        }
        loadCanFinish.open()
        let firstResult = await firstLoad.value
        let cachedResult = await viewModel.permittedVersions {
            loadCount += 1
            return []
        }

        #expect(concurrentResult == nil)
        #expect(firstResult == [])
        #expect(cachedResult == [])
        #expect(loadCount == 1)
    }

    @Test
    func excludedVersionIsNotPermitted() {
        let originalAppKey = YouVersionPlatformConfiguration.appKey
        YouVersionPlatformConfiguration.configure(
            appKey: originalAppKey,
            permittedVersionIds: [4212, 4213],
            excludedVersionIds: [4212]
        )
        defer {
            YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
        let viewModel = BibleVersionsViewModel()

        #expect(!viewModel.isPermitted(versionId: 4212, languageTag: "en"))
        #expect(viewModel.isPermitted(versionId: 4213, languageTag: "en"))
    }

    @Test
    func handleVersionPickerTapLoadsSelectedVersionAndPushesInfoScreen() async {
        let repository = MockBibleVersionRepository()
        let version = makeBibleVersion(id: 222)
        await repository.setVersion(version)
        let viewModel = BibleVersionsViewModel(versionRepository: repository)

        await viewModel.handleVersionPickerTap(version.id)

        #expect(viewModel.selectedVersion == version)
        #expect(viewModel.versionsPickerStack == [.versionInfo])
        #expect(viewModel.showingVersionsStack)
        #expect(viewModel.showFullProgressViewOverlay == false)
    }

    @Test
    func myVersionMoreInfoMenuTappedUsesInjectedRepository() async {
        let repository = MockBibleVersionRepository()
        let version = makeBibleVersion(id: 333)
        await repository.setVersion(version)
        let viewModel = BibleVersionsViewModel(versionRepository: repository)

        await viewModel.myVersionMoreInfoMenuTapped(version.id)

        #expect(viewModel.selectedVersion == version)
        #expect(viewModel.versionsPickerStack == [.versionInfo])
        #expect(viewModel.showingVersionsStack)
    }

    @Test
    func myVersionDownloadMenuTappedShowsAlertWhenRepositoryCannotLoadVersion() async {
        let repository = MockBibleVersionRepository()
        let viewModel = BibleVersionsViewModel(versionRepository: repository)

        await viewModel.myVersionDownloadMenuTapped(444)

        #expect(viewModel.showGenericAlert)
        #expect(viewModel.textForGenericAlertTitle == .localized("generic.error"))
        #expect(viewModel.textForGenericAlertBody == .localized("myVersions.downloadErrorBody"))
    }

    private func makeBibleVersion(id: Int) -> BibleVersion {
        BibleVersion(
            id: id,
            abbreviation: "XYZ\(id)",
            promotionalContent: nil,
            copyright: nil,
            languageTag: "en",
            localizedAbbreviation: "Xyz\(id)",
            localizedTitle: "The Something Bible \(id)",
            readerFooter: nil,
            readerFooterUrl: nil,
            title: "Something Bible \(id)",
            organizationId: nil,
            bookCodes: nil,
            books: nil,
            textDirection: "ltr"
        )
    }
}
