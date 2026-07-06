import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader
@testable import YouVersionPlatformUI

@MainActor
@Suite(.serialized) struct BibleReaderViewModelDataExchangeTests {
    private typealias Support = BibleReaderViewModelTestSupport

    @Test
    func addHighlightProceedsImmediatelyWhenHighlightPermissionIsGranted() {
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(
            highlightsRepository: highlightsRepository,
            isSignedIn: true,
            hasPermission: { $0 == .highlights }
        )
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]
        viewModel.showingVerseActionsDrawer = true

        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")

        #expect(viewModel.highlightsViewModel.highlights(for: reference) == [BibleHighlight(reference, color: "DDAAFF")])
        #expect(highlightsRepository.queuedOperations.first?.operationType == .add)
        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingDataExchangeConfirmation == false)
        #expect(viewModel.startDataExchangeFlow == false)
    }

    @Test
    func signedInUserWithoutHighlightPermissionStoresPendingHighlightAndShowsConfirmation() {
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository, isSignedIn: true)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]

        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")

        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
        #expect(highlightsRepository.queuedOperations.isEmpty)
        #expect(viewModel.selectedVerses == [reference])
        #expect(viewModel.showingDataExchangeConfirmation)
        #expect(viewModel.startDataExchangeFlow == false)
    }

    @Test
    func cancellingDataExchangePromptClearsPendingHighlightWithoutCreatingHighlights() {
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository, isSignedIn: true)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]
        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")

        viewModel.cancelDataExchangePrompt()
        viewModel.completeDataExchangeFlow(with: DataExchangeRequestResult(status: .granted, grantedPermissions: [.highlights]))

        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
        #expect(highlightsRepository.queuedOperations.isEmpty)
        #expect(viewModel.showingDataExchangeConfirmation == false)
        #expect(viewModel.startDataExchangeFlow == false)
    }

    @Test
    func confirmingDataExchangePromptStartsBrowserFlow() {
        let viewModel = Support.makeViewModel(isSignedIn: true)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]
        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")

        viewModel.confirmDataExchangePrompt()

        #expect(viewModel.showingDataExchangeConfirmation == false)
        #expect(viewModel.startDataExchangeFlow)
    }

    @Test
    func grantedDataExchangeFlowAppliesPendingHighlightAndClearsSelection() {
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository, isSignedIn: true)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]
        viewModel.showingVerseActionsDrawer = true
        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")
        viewModel.confirmDataExchangePrompt()

        viewModel.completeDataExchangeFlow(with: DataExchangeRequestResult(status: .granted, grantedPermissions: [.highlights]))

        #expect(viewModel.highlightsViewModel.highlights(for: reference) == [BibleHighlight(reference, color: "DDAAFF")])
        #expect(highlightsRepository.queuedOperations.first?.operationType == .add)
        #expect(viewModel.selectedVerses.isEmpty)
        #expect(viewModel.showingVerseActionsDrawer == false)
        #expect(viewModel.startDataExchangeFlow == false)
    }

    @Test
    func cancelledDataExchangeFlowDoesNotApplyPendingHighlight() {
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository, isSignedIn: true)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]
        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")
        viewModel.confirmDataExchangePrompt()

        viewModel.completeDataExchangeFlow(with: DataExchangeRequestResult(status: .cancel, grantedPermissions: []))

        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
        #expect(highlightsRepository.queuedOperations.isEmpty)
        #expect(viewModel.selectedVerses == [reference])
        #expect(viewModel.startDataExchangeFlow == false)
    }

    @Test
    func unknownDataExchangeStatusDoesNotApplyPendingHighlight() {
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository, isSignedIn: true)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]
        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")
        viewModel.confirmDataExchangePrompt()

        viewModel.completeDataExchangeFlow(with: DataExchangeRequestResult(status: .unknown("needs_review"), grantedPermissions: [.highlights]))

        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
        #expect(highlightsRepository.queuedOperations.isEmpty)
        #expect(viewModel.selectedVerses == [reference])
        #expect(viewModel.startDataExchangeFlow == false)
    }

    @Test
    func grantedDataExchangeFlowWithoutHighlightsPermissionDoesNotApplyPendingHighlight() {
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository, isSignedIn: true)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]
        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")
        viewModel.confirmDataExchangePrompt()

        viewModel.completeDataExchangeFlow(with: DataExchangeRequestResult(status: .granted, grantedPermissions: [.unknown("notes")]))

        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
        #expect(highlightsRepository.queuedOperations.isEmpty)
        #expect(viewModel.selectedVerses == [reference])
        #expect(viewModel.startDataExchangeFlow == false)
    }

    @Test
    func signedOutUserShowsSignInSheetBeforeShowingDataExchangeConfirmation() {
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: true)
        let highlightsRepository = MockBibleHighlightsRepository()
        let viewModel = Support.makeViewModel(highlightsRepository: highlightsRepository, isSignedIn: false)
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]

        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")

        #expect(viewModel.showingSignInSheet)
        #expect(viewModel.startSignInFlow == false)
        #expect(viewModel.showingDataExchangeConfirmation == false)
        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
        #expect(highlightsRepository.queuedOperations.isEmpty)
    }

    @Test
    func pendingHighlightStartsDataExchangeFlowDirectlyAfterSignInSucceeds() async {
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: true)
        let highlightsRepository = MockBibleHighlightsRepository()
        let authenticationState = MockBibleReaderAuthenticationState(isSignedIn: false)
        let viewModel = Support.makeViewModel(
            highlightsRepository: highlightsRepository,
            readIsSignedIn: { authenticationState.isSignedIn },
            hasValidToken: true
        )
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.selectedVerses = [reference]
        viewModel.addHighlightOrStartPermissionFlow(references: [reference], color: "DDAAFF")

        authenticationState.isSignedIn = true
        await viewModel.updateSignInState()
        viewModel.continuePendingHighlightAfterSignIn()

        #expect(viewModel.isSignedIn)
        #expect(viewModel.startDataExchangeFlow)
        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
        #expect(highlightsRepository.queuedOperations.isEmpty)
    }
}
