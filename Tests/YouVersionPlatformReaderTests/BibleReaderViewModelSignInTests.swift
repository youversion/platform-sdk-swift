import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
@Suite(.serialized) struct BibleReaderViewModelSignInTests {
    private typealias Support = BibleReaderViewModelTestSupport

    @Test
    func handleVerseTapShowsSignInSheetWhenUnsignedOutAndSignInEnabled() {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel(isSignedIn: false)

        viewModel.handleVerseTap(
            reference: BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3, verse: 16),
            actionType: "",
            footnotes: []
        )

        // A signed-out tap prompts sign-in rather than selecting the verse.
        #expect(viewModel.showingSignInSheet)
        #expect(viewModel.showingVerseActionsDrawer == false)
        #expect(viewModel.selectedVerses.isEmpty)
    }

    @Test
    func handleVerseTapDoesNothingWhenUnsignedOutAndSignInDisabled() {
        Support.clearReaderDefaults()
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: false)
        defer {
            YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: true)
        }
        let viewModel = Support.makeViewModel(isSignedIn: false)

        viewModel.handleVerseTap(
            reference: BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3, verse: 16),
            actionType: "",
            footnotes: []
        )

        #expect(viewModel.showingSignInSheet == false)
        #expect(viewModel.showingVerseActionsDrawer == false)
        #expect(viewModel.selectedVerses.isEmpty)
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
    func signInReadsCurrentAuthenticationState() {
        Support.clearReaderDefaults()
        let authenticationState = MockBibleReaderAuthenticationState(isSignedIn: false)
        let viewModel = Support.makeViewModel(readIsSignedIn: { authenticationState.isSignedIn })
        authenticationState.isSignedIn = true

        viewModel.signIn()

        #expect(viewModel.startSignInFlow == false)
        #expect(viewModel.isSignedIn)
    }

    @Test
    func signOutShowsPendingHighlightsConfirmationAndConfirmClearsStateAndHighlights() {
        Support.clearReaderDefaults()
        let authenticationState = MockBibleReaderAuthenticationState(isSignedIn: true)
        var didSignOut = false
        let viewModel = Support.makeViewModel(
            readIsSignedIn: { authenticationState.isSignedIn },
            signOut: {
                didSignOut = true
                authenticationState.isSignedIn = false
            }
        )
        let reference = BibleReference(versionId: Support.versionId, bookId: "JHN", chapter: 3, verse: 16)
        viewModel.highlightsViewModel.addHighlights(references: [reference], color: "DDAAFF")

        #expect(viewModel.isSignedIn)

        viewModel.signOut()
        #expect(viewModel.showSignOutWithPendingHighlightsConfirmation)

        viewModel.confirmPendingHighlightsSignOut()

        #expect(didSignOut)
        #expect(viewModel.isSignedIn == false)
        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
    }

    @Test
    func updateSignInStateUsesAuthenticationState() async {
        Support.clearReaderDefaults()
        var didValidateToken = false
        let viewModel = Support.makeViewModel(validateToken: {
            didValidateToken = true
            return true
        })

        await viewModel.updateSignInState()

        #expect(didValidateToken)
    }
}
