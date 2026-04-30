import SwiftUI
import YouVersionPlatform

@main
struct SampleApp: App {

    @State private var selectedTab = 0

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
                BibleReaderView()
                .tabItem {
                    Label("Bible", systemImage: "book.closed.fill")
                }
                .tag(0)

                VotdContainerView()
                    .tabItem {
                        Label("VOTD", systemImage: "sun.max.fill")
                    }
                    .tag(1)

                CardView()
                    .tabItem {
                        Label("Card", systemImage: "doc.plaintext")
                    }
                    .tag(2)

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(3)
            }
        }
    }
}
