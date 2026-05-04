import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderHeaderMenuView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        Group {
            if YouVersionPlatformConfiguration.isSignInEnabled {
                HStack(spacing: 0) {
                    fontSettingsButton
                    accountMenu
                }
            } else {
                fontSettingsButton
            }
        }
        .onAppear {
            viewModel.updateSignInState()
        }
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
        .accessibilityLabel(String.localized("reader.header.accountMenu"))
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

#Preview {
    BibleReaderHeaderMenuView()
        .environment(BibleReaderViewModel.preview)
}
