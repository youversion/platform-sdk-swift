import SwiftUI
import YouVersionPlatform

@main
struct SampleApp: App {

    @State private var selectedTab = 0
    @State private var readerNavigation = BibleReaderNavigation()

    init() {
        // Get your app key from https://platform.youversion.com/
        YouVersionPlatformConfiguration.configure(
            appKey: <#Your App Key#>,
            appName: "Sample App",
            signInPromptMessage: "Sign in to see your YouVersion highlights in this Sample App."
        )
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                BibleReaderView.restoringLastPassage(readerNavigation: readerNavigation)
                .tabItem {
                    Label("Bible", systemImage: "book.closed.fill")
                }
                .tag(0)

                NavigateView(navigation: readerNavigation, onNavigate: { selectedTab = 0 })
                    .tabItem {
                        Label("Navigate", systemImage: "arrow.uturn.right")
                    }
                    .tag(1)

                VotdContainerView()
                    .tabItem {
                        Label("VOTD", systemImage: "sun.max.fill")
                    }
                    .tag(2)

                CardView()
                    .tabItem {
                        Label("Card", systemImage: "doc.plaintext")
                    }
                    .tag(3)

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(4)
            }
            .tint(.red)
        }
    }
}
