import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
@Suite(.serialized) struct BibleReaderViewModelSignInTests {
    private typealias Support = BibleReaderViewModelTestSupport

    @Test
    func handleVerseTapPromptsForSignInWhenUnsignedOutAndSignInEnabled() {
        Support.clearReaderDefaults()
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: true)
        let viewModel = Support.makeViewModel(isSignedIn: false)

        viewModel.handleVerseTap(
            reference: BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16),
            actionType: "",
            footnotes: []
        )

        #expect(viewModel.showingSignInSheet)
        #expect(viewModel.selectedVerses.isEmpty)
    }

    @Test
    func handleVerseTapDoesNothingWhenUnsignedOutAndSignInDisabled() {
        Support.clearReaderDefaults()
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: false)
        let viewModel = Support.makeViewModel(isSignedIn: false)

        viewModel.handleVerseTap(
            reference: BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16),
            actionType: "",
            footnotes: []
        )

        #expect(viewModel.showingSignInSheet == false)
        #expect(viewModel.selectedVerses.isEmpty)
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: true)
    }

    @Test
    func signInStartsFlowOnlyWhenSignedOut() {
        Support.clearReaderDefaults()
        let signedOutViewModel = Support.makeViewModel(isSignedIn: false)

        signedOutViewModel.signIn()

        #expect(signedOutViewModel.startSignInFlow)

        let signedInViewModel = Support.makeViewModel(isSignedIn: true)

        signedInViewModel.signIn()

        #expect(signedInViewModel.startSignInFlow == false)
    }

    @Test
    func signOutShowsConfirmationAndConfirmSignOutClearsStateAndHighlights() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel()
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.highlightsViewModel.addHighlights(references: [reference], color: "DDAAFF")

        viewModel.signOut()
        #expect(viewModel.showSignOutConfirmation)

        viewModel.confirmSignOut()

        #expect(viewModel.isSignedIn == false)
        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
    }

    @Test
    func updateSignInStateUsesAuthenticationState() async {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel(hasValidToken: true)

        await viewModel.updateSignInState()

        #expect(viewModel.isSignedIn)
    }
}
