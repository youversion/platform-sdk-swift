import SwiftUI
import YouVersionPlatformCore

struct BibleReaderHeaderMenuView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @State private var observedIsSignedIn: Bool?

    var body: some View {
        Menu {
            Button(String.localized("menu.fontSettings"), action: openFontSettings)
            if YouVersionPlatformConfiguration.isSignInEnabled {
                if isSignedIn {
                    Button(String.localized("menu.signOut"), role: .destructive, action: signOut)
                } else {
                    Button(String.localized("menu.signIn"), action: signIn)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .padding()
        }
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

#Preview {
    BibleReaderHeaderMenuView()
        .environment(BibleReaderViewModel.preview)
}
