import SwiftUI
import YouVersionPlatformCore

struct BibleReaderHeaderMenuView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        Menu {
            Button(String.localized("menu.fontSettings"), action: openFontSettings)
            if viewModel.isSignedIn {
                Button(String.localized("menu.signOut"), role: .destructive, action: signOut)
            } else {
                Button(String.localized("menu.signIn"), action: signIn)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .padding()
        }
        .onAppear {
            viewModel.updateSignInState()
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

#Preview {
    BibleReaderHeaderMenuView()
        .environment(BibleReaderViewModel.preview)
}
