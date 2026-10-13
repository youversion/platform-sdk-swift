import SwiftUI
import YouVersionPlatformCore

struct BibleReaderHeaderMenuView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @State private var observedIsSignedIn: Bool?
    var actions: [BibleReaderNavigationAction] = []

    var body: some View {
        Menu {
            ForEach(actions, id: \.self) { action in
                ReaderNavigationActionButton(action: action, isMenuItem: true)
            }
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
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("readerMenuBtn")
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
