import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
@Suite(.serialized) struct BibleReaderViewModelNavigationStateTests {
    private typealias Support = BibleReaderViewModelTestSupport

    @Test
    func onHeaderSelectionChangeUpdatesReferenceAndResetsReaderState() async {
        let repository = MockBibleVersionRepository()
        let viewModel = Support.makeViewModel(versionRepository: repository)
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))
        let selectedReference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1, verse: 1)
        viewModel.selectedVerses = [selectedReference]
        viewModel.showingVerseActionsDrawer = true
        viewModel.showChrome = false
        viewModel.lastScrollOffset = -100

        let newReference = BibleReference(versionId: 111, bookUSFM: "JHN", chapter: 3)
        await viewModel.onHeaderSelectionChange(newReference, showIntro: true)

        #expect(viewModel.reference == newReference)
        #expect(viewModel.showBookIntro)
        #expect(viewModel.versionsViewModel.currentVersion == Support.makeBibleVersion(id: 111))
        #expect(viewModel.versionsViewModel.myVersions.contains(Support.makeBibleVersion(id: 111)))
        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
        #expect(viewModel.showChrome)
        #expect(viewModel.lastScrollOffset == 0)
        #expect(viewModel.scrollToTop)
        #expect(await repository.requestedIds() == [111])
    }

    @Test
    func onHeaderSelectionChangeDoesNotMutateStateWhenRepositoryThrows() async {
        let repository = MockBibleVersionRepository()
        await repository.setThrownError(TestError())
        let originalReference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1)
        let viewModel = Support.makeViewModel(reference: originalReference, versionRepository: repository)
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))

        await viewModel.onHeaderSelectionChange(BibleReference(versionId: 111, bookUSFM: "JHN", chapter: 3), showIntro: true)

        #expect(viewModel.reference == originalReference)
        #expect(viewModel.showBookIntro == false)
        #expect(await repository.requestedIds() == [111])
    }

    @Test
    func handleVersionPickedNoOpsWhenVersionIsUnchanged() async {
        let viewModel = Support.makeViewModel()
        let selectedReference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1, verse: 1)
        viewModel.versionsViewModel.switchToVersion(Support.makeBibleVersion(id: Support.versionId))
        viewModel.selectedVerses = [selectedReference]
        viewModel.showingVerseActionsDrawer = true

        await viewModel.handleVersionPicked(Support.makeBibleVersion(id: Support.versionId))

        #expect(viewModel.reference == BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 1))
        #expect(viewModel.selectedVerses == [selectedReference])
        #expect(viewModel.showingVerseActionsDrawer)
    }

    @Test
    func handleVersionPickedUpdatesReferenceVersionAndLoadsSelection() async {
        let repository = MockBibleVersionRepository()
        let viewModel = Support.makeViewModel(versionRepository: repository)

        await viewModel.handleVersionPicked(Support.makeBibleVersion(id: 111))

        #expect(viewModel.reference == BibleReference(versionId: 111, bookUSFM: "JHN", chapter: 1))
        #expect(viewModel.versionsViewModel.currentVersion == Support.makeBibleVersion(id: 111))
        #expect(await repository.requestedIds() == [111])
    }

    @Test
    func versionsSignInCallbackStartsSignInFlow() {
        let viewModel = Support.makeViewModel()

        viewModel.versionsViewModel.onSignInRequired?()

        #expect(viewModel.startSignInFlow)
    }
}
