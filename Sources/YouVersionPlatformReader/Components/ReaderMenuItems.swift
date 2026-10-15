import SwiftUI
import YouVersionPlatformCore

/// Settings and authentication actions shared by custom and system overflow menus.
struct ReaderMenuItems: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.readerIsSignedIn) private var isSignedIn

    var body: some View {
        Group {
            Button(String.localized("menu.fontSettings"), action: openFontSettings)
            if YouVersionPlatformConfiguration.isSignInEnabled {
                if isSignedIn {
                    Button(String.localized("menu.signOut"), role: .destructive, action: signOut)
                } else {
                    Button(String.localized("menu.signIn"), action: signIn)
                }
            }
        }
    }

    private func openFontSettings() {
        viewModel.openFontSettings()
    }

    private func signOut() {
        viewModel.signOut()
    }

    private func signIn() {
        viewModel.signIn()
    }
}

extension EnvironmentValues {
    @Entry var readerIsSignedIn = false
}
