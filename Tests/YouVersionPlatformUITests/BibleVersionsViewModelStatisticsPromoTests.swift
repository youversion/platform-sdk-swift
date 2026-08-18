import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformUI

/// Stands in for the permitted-versions network request so tests can count how
/// many times a view model attempts it, and hold an attempt open to overlap callers.
@MainActor
private final class PermittedVersionsStub {
    private(set) var callCount = 0
    var result: Result<[YouVersionAPI.Bible.BibleVersionMinimalInfo], any Error>

    /// When true, each attempt suspends until ``openGate()`` is called.
    var isGated = false
    var hasWaitingCaller: Bool { !gate.isEmpty }

    /// Every suspended attempt, so that an unexpected extra attempt fails an
    /// expectation rather than deadlocking the test.
    private var gate: [CheckedContinuation<Void, Never>] = []

    init(result: Result<[YouVersionAPI.Bible.BibleVersionMinimalInfo], any Error> = .success([])) {
        self.result = result
    }

    func permittedVersions() async throws -> [YouVersionAPI.Bible.BibleVersionMinimalInfo] {
        callCount += 1
        if isGated {
            await withCheckedContinuation { gate.append($0) }
        }
        return try result.get()
    }

    func openGate() {
        isGated = false
        for continuation in gate {
            continuation.resume()
        }
        gate = []
    }
}

extension BibleVersionsViewModelTests {

    // MARK: - The statistics promo is side-effect free

    @Test
    func statisticsPromoIsEmptyAndStartsNoFetchWhenRepeatedlyRead() async {
        let stub = PermittedVersionsStub(result: .success(makeMinimalInfos()))
        let viewModel = makeViewModel(fetchingWith: stub)

        for _ in 0..<5 {
            #expect(viewModel.bibleVersionStatisticsPromo.isEmpty)
        }
        await settle()

        #expect(stub.callCount == 0)
        #expect(viewModel.bibleVersionStatisticsPromo.isEmpty)
    }

    @Test
    func statisticsPromoDescribesLoadedVersionsWithoutRefetching() async {
        let stub = PermittedVersionsStub(result: .success(makeMinimalInfos()))
        let viewModel = makeViewModel(fetchingWith: stub)

        _ = await viewModel.permittedVersions()

        // `swift test` doesn't compile the string catalog, so the promo's wording
        // isn't available here; only its presence and stability can be checked.
        let promo = viewModel.bibleVersionStatisticsPromo
        #expect(!promo.isEmpty)
        #expect(viewModel.cachedPermittedVersions == makeMinimalInfos())

        for _ in 0..<5 {
            #expect(viewModel.bibleVersionStatisticsPromo == promo)
        }
        await settle()

        #expect(stub.callCount == 1)
    }

    // MARK: - One attempt per view model instance

    @Test
    func permittedVersionsFetchesOnceAcrossRepeatedCalls() async {
        let stub = PermittedVersionsStub(result: .success(makeMinimalInfos()))
        let viewModel = makeViewModel(fetchingWith: stub)

        let first = await viewModel.permittedVersions()
        let second = await viewModel.permittedVersions()
        let third = await viewModel.permittedVersions()

        #expect(stub.callCount == 1)
        #expect(first == makeMinimalInfos())
        #expect(second == first)
        #expect(third == first)
    }

    @Test
    func simultaneousPermittedVersionsCallsShareOneFetch() async {
        let stub = PermittedVersionsStub(result: .success(makeMinimalInfos()))
        stub.isGated = true
        let viewModel = makeViewModel(fetchingWith: stub)

        async let first = viewModel.permittedVersions()
        async let second = viewModel.permittedVersions()
        async let third = viewModel.permittedVersions()

        while !stub.hasWaitingCaller {
            await Task.yield()
        }
        stub.openGate()
        let results = await [first, second, third]

        #expect(stub.callCount == 1)
        #expect(results.allSatisfy { $0 == makeMinimalInfos() })
        #expect(viewModel.cachedPermittedVersions == makeMinimalInfos())
    }

    @Test
    func emptySuccessIsCachedAndNotRefetched() async {
        let stub = PermittedVersionsStub(result: .success([]))
        let viewModel = makeViewModel(fetchingWith: stub)

        let versions = await viewModel.permittedVersions()

        #expect(versions == [])
        #expect(viewModel.cachedPermittedVersions == [])
        #expect(viewModel.bibleVersionStatisticsPromo.isEmpty)

        _ = await viewModel.permittedVersions()
        _ = viewModel.bibleVersionStatisticsPromo
        await settle()

        #expect(stub.callCount == 1)
    }

    @Test
    func offlineFailureIsNotRetriedWithinTheRetryInterval() async {
        let stub = PermittedVersionsStub(result: .failure(URLError(.notConnectedToInternet)))
        let viewModel = makeViewModel(fetchingWith: stub)

        let versions = await viewModel.permittedVersions()

        #expect(versions == nil)
        #expect(viewModel.cachedPermittedVersions == nil)
        #expect(viewModel.bibleVersionStatisticsPromo.isEmpty)

        for _ in 0..<5 {
            #expect(viewModel.bibleVersionStatisticsPromo.isEmpty)
        }
        _ = await viewModel.permittedVersions()
        viewModel.openVersionsStack(currentBibleLanguage: "en")
        viewModel.versionsStackPush(to: .moreVersions)
        _ = await viewModel.permittedVersions(currentDate: Date().addingTimeInterval(59))
        await settle()

        #expect(stub.callCount == 1)
    }

    @Test
    func offlineFailureIsRetriedOnceTheRetryIntervalHasPassed() async {
        let stub = PermittedVersionsStub(result: .failure(URLError(.notConnectedToInternet)))
        let viewModel = makeViewModel(fetchingWith: stub)
        let startTime = Date()

        _ = await viewModel.permittedVersions(currentDate: startTime)
        #expect(stub.callCount == 1)

        // Back online by the time the interval is up.
        stub.result = .success(makeMinimalInfos())
        let versions = await viewModel.permittedVersions(currentDate: startTime.addingTimeInterval(61))

        #expect(stub.callCount == 2)
        #expect(versions == makeMinimalInfos())
        #expect(!viewModel.bibleVersionStatisticsPromo.isEmpty)
    }

    @Test
    func repeatedFailuresRequestOnlyOncePerRetryInterval() async {
        let stub = PermittedVersionsStub(result: .failure(URLError(.notConnectedToInternet)))
        let viewModel = makeViewModel(fetchingWith: stub)
        let startTime = Date()

        // Three minutes of the user moving through the picker, a trip every 10 seconds.
        for step in 0..<18 {
            _ = await viewModel.permittedVersions(currentDate: startTime.addingTimeInterval(Double(step) * 10))
        }
        await settle()

        #expect(stub.callCount == 3)
        #expect(viewModel.bibleVersionStatisticsPromo.isEmpty)
    }

    // MARK: - Loading is driven by the version-picking UI path

    @Test
    func openingTheVersionsStackLoadsPermittedVersionsOnce() async {
        let stub = PermittedVersionsStub(result: .success(makeMinimalInfos()))
        let viewModel = makeViewModel(fetchingWith: stub)

        viewModel.openVersionsStack(currentBibleLanguage: "en")
        _ = await viewModel.permittedVersions()

        #expect(stub.callCount == 1)
        #expect(!viewModel.bibleVersionStatisticsPromo.isEmpty)
    }

    @Test
    func movingThroughTheVersionPickerLoadsPermittedVersionsOnce() async {
        let stub = PermittedVersionsStub(result: .success(makeMinimalInfos()))
        let viewModel = makeViewModel(fetchingWith: stub)

        viewModel.versionsStackPush(to: .moreVersions)
        viewModel.versionsStackPush(to: .versionInfo)
        _ = await viewModel.permittedVersions()
        await settle()

        #expect(stub.callCount == 1)
        #expect(!viewModel.bibleVersionStatisticsPromo.isEmpty)
    }

    // MARK: - Helpers

    private func makeViewModel(fetchingWith stub: PermittedVersionsStub) -> BibleVersionsViewModel {
        let viewModel = BibleVersionsViewModel()
        viewModel.permittedVersionsProvider = stub.permittedVersions
        return viewModel
    }

    /// Three versions in two languages.
    private func makeMinimalInfos() -> [YouVersionAPI.Bible.BibleVersionMinimalInfo] {
        [
            .init(id: 5551, languageTag: "en"),
            .init(id: 5552, languageTag: "en"),
            .init(id: 5553, languageTag: "de")
        ]
    }

    /// Gives any already-spawned task a chance to run, so a test observes the
    /// requests it would have made.
    private func settle() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }
}
