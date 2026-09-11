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
            appName: String(localized: "app.name"),
            signInPromptMessage: String(localized: "app.sign_in_prompt")
        )
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                BibleReaderView.restoringLastPassage(readerNavigation: readerNavigation)
                .tabItem {
                    Label("tab.bible", systemImage: "book.closed.fill")
                }
                .tag(0)

                NavigateView(navigation: readerNavigation, onNavigate: { selectedTab = 0 })
                    .tabItem {
                        Label("tab.navigate", systemImage: "arrow.uturn.right")
                    }
                    .tag(1)

                VotdContainerView()
                    .tabItem {
                        Label("tab.votd", systemImage: "sun.max.fill")
                    }
                    .tag(2)

                CardView()
                    .tabItem {
                        Label("tab.card", systemImage: "doc.plaintext")
                    }
                    .tag(3)

                ProfileView()
                    .tabItem {
                        Label("tab.profile", systemImage: "person.fill")
                    }
                    .tag(4)
            }
        }
    }
}
