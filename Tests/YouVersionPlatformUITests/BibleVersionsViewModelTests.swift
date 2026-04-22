import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

private actor MockBibleVersionRepository: BibleVersionRepositoryProtocol {
    var versionById: [Int: BibleVersion] = [:]
    var cachedVersionById: [Int: BibleVersion] = [:]
    var thrownError: Error?
    var downloadedIds: [Int] = []

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

    func removeVersion(withId versionId: Int) async {
    }

    func removeUnpermittedVersions(permittedIds: Set<Int>) async {
    }
}

@MainActor
@Suite struct BibleVersionsViewModelTests {
    @Test
    func initUsesSharedRepositoryByDefault() {
        let viewModel = BibleVersionsViewModel { _ in }

        #expect(viewModel.versionRepository is BibleVersionRepository)
    }

    @Test
    func switchToVersionUsesInjectedRepository() async {
        let repository = MockBibleVersionRepository()
        let version = makeBibleVersion(id: 111)
        await repository.setVersion(version)
        var changedVersion: BibleVersion?
        let viewModel = BibleVersionsViewModel(
            onVersionChange: { changedVersion = $0 },
            versionRepository: repository
        )

        viewModel.switchToVersion(version.id)
        await waitFor { changedVersion == version }

        #expect(changedVersion == version)
        #expect(viewModel.showGenericAlert == false)
    }

    @Test
    func switchToVersionShowsAlertWhenRepositoryThrows() async {
        let repository = MockBibleVersionRepository()
        await repository.setThrownError(NSError(domain: "BibleVersionsViewModelTests", code: 99))
        let viewModel = BibleVersionsViewModel(
            onVersionChange: { _ in Issue.record("onVersionChange should not be called") },
            versionRepository: repository
        )

        viewModel.switchToVersion(111)
        await waitFor { viewModel.showGenericAlert }

        #expect(viewModel.showGenericAlert)
        #expect(viewModel.textForGenericAlertTitle == .localized("generic.error"))
        #expect(viewModel.textForGenericAlertBody == .localized("reader.versionAccessErrorBody"))
    }

    @Test
    func handleVersionPickerTapLoadsSelectedVersionAndPushesInfoScreen() async {
        let repository = MockBibleVersionRepository()
        let version = makeBibleVersion(id: 222)
        await repository.setVersion(version)
        let viewModel = BibleVersionsViewModel(
            onVersionChange: { _ in },
            versionRepository: repository
        )

        viewModel.handleVersionPickerTap(version.id)
        await waitFor { viewModel.selectedVersion == version }

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
        let viewModel = BibleVersionsViewModel(
            onVersionChange: { _ in },
            versionRepository: repository
        )

        viewModel.myVersionMoreInfoMenuTapped(version.id)
        await waitFor { viewModel.selectedVersion == version }

        #expect(viewModel.selectedVersion == version)
        #expect(viewModel.versionsPickerStack == [.versionInfo])
        #expect(viewModel.showingVersionsStack)
    }

    @Test
    func myVersionDownloadMenuTappedShowsAlertWhenRepositoryCannotLoadVersion() async {
        let repository = MockBibleVersionRepository()
        let viewModel = BibleVersionsViewModel(
            onVersionChange: { _ in Issue.record("onVersionChange should not be called") },
            versionRepository: repository
        )

        viewModel.myVersionDownloadMenuTapped(444)
        await waitFor { viewModel.showGenericAlert }

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

    private func waitFor(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Timed out waiting for condition")
    }
}
