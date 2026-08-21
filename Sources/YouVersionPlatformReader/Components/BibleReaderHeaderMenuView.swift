import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderHeaderMenuView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @State private var observedIsSignedIn: Bool?

    var body: some View {
        Group {
            if YouVersionPlatformConfiguration.isSignInEnabled {
                if isSignedIn {
                    Button(String.localized("menu.signOut"), role: .destructive, action: signOut)
                } else {
                    Button(String.localized("menu.signIn"), action: signIn)
                }
            } else {
                fontSettingsButton
            }
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

    private var fontSettingsButton: some View {
        Button(action: openFontSettings) {
            Image(systemName: "gearshape")
                .imageScale(.large)
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .padding()
        }
        .accessibilityLabel(String.localized("menu.fontSettings"))
    }

    private var accountMenu: some View {
        Menu {
            if viewModel.isSignedIn {
                Button(String.localized("menu.signOut"), role: .destructive, action: signOut)
            } else {
                Button(String.localized("menu.signIn"), action: signIn)
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .imageScale(.large)
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .padding()
        }
        .accessibilityLabel(String.localized("menu.account"))
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
