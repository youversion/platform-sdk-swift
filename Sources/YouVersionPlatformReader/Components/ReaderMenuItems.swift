import SwiftUI
import YouVersionPlatformCore

/// Settings and authentication actions shared by custom and system overflow menus.
struct ReaderMenuItems: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @State private var observedIsSignedIn: Bool?

    var body: some View {
        Group {
            Button(String.localized("menu.fontSettings"), action: openFontSettings)
                .task {
                    await updateSignInState()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: YouVersionPlatformConfiguration.authStateDidChangeNotification)
                ) { _ in
                    Task {
                        await updateSignInState()
                    }
                }
            if YouVersionPlatformConfiguration.isSignInEnabled {
                if isSignedIn {
                    Button(String.localized("menu.signOut"), role: .destructive, action: signOut)
                } else {
                    Button(String.localized("menu.signIn"), action: signIn)
                }
            }
        }
    }

    private var isSignedIn: Bool {
        observedIsSignedIn ?? viewModel.isSignedIn
    }

    private func openFontSettings() {
        viewModel.openFontSettings()
    }

    @MainActor
    private func updateSignInState() async {
        await viewModel.updateSignInState()
        observedIsSignedIn = viewModel.isSignedIn
    }

    private func signOut() {
        viewModel.signOut()
    }

    private func signIn() {
        viewModel.signIn()
    }
}
