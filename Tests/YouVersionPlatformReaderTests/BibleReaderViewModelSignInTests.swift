import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
@Suite(.serialized) struct BibleReaderViewModelSignInTests {
    private typealias Support = BibleReaderViewModelTestSupport

    @Test
    func handleVerseTapPromptsForSignInWhenUnsignedOutAndSignInEnabled() {
        Support.clearReaderDefaults()
        YouVersionPlatformConfiguration.clearAuthTokens()
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: true)
        let viewModel = Support.makeViewModel()

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
        YouVersionPlatformConfiguration.clearAuthTokens()
        YouVersionPlatformConfiguration.configure(appKey: "test-app", isSignInEnabled: false)
        let viewModel = Support.makeViewModel()

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
        YouVersionPlatformConfiguration.clearAuthTokens()
        let viewModel = Support.makeViewModel()

        viewModel.signIn()
        #expect(viewModel.startSignInFlow)

        viewModel.startSignInFlow = false
        YouVersionPlatformConfiguration.saveAuthData(
            accessToken: "access-token",
            refreshToken: nil,
            idToken: nil,
            expiryDate: nil
        )

        viewModel.signIn()

        #expect(viewModel.startSignInFlow == false)
        YouVersionPlatformConfiguration.clearAuthTokens()
    }

    @Test
    func signOutShowsConfirmationAndConfirmSignOutClearsAuthAndHighlights() {
        Support.clearReaderDefaults()
        YouVersionPlatformConfiguration.saveAuthData(
            accessToken: "access-token",
            refreshToken: nil,
            idToken: nil,
            expiryDate: nil
        )
        let viewModel = Support.makeViewModel()
        let reference = BibleReference(versionId: Support.versionId, bookUSFM: "JHN", chapter: 3, verse: 16)
        viewModel.highlightsViewModel.addHighlights(references: [reference], color: "DDAAFF")

        viewModel.signOut()
        #expect(viewModel.showSignOutConfirmation)

        viewModel.confirmSignOut()

        #expect(YouVersionAPI.isSignedIn == false)
        #expect(viewModel.highlightsViewModel.highlights(for: reference).isEmpty)
    }

    @Test
    func updateSignInStateUsesCurrentTokenState() async {
        Support.clearReaderDefaults()
        let viewModel = Support.makeViewModel()
        YouVersionPlatformConfiguration.saveAuthData(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            idToken: nil,
            expiryDate: Date().addingTimeInterval(60)
        )

        viewModel.updateSignInState()
        await Support.waitUntil("sign-in state to update") {
            viewModel.isSignedIn
        }

        #expect(viewModel.isSignedIn)
        YouVersionPlatformConfiguration.clearAuthTokens()
    }
}
