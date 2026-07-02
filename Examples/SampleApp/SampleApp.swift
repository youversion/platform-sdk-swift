import SwiftUI
import YouVersionPlatform

@main
struct SampleApp: App {

    @State private var selectedTab = 0

    init() {
        // Get your app key from https://platform.youversion.com/
        YouVersionPlatformConfiguration.configure(
            appKey: "zvpcDUhgrpapAfXkPpEcJs7stJY1SKOgO5CrzwSQuW8EVGGo",  // prod
//            appKey: "nqAVz0UI8PezoWtcuHHqISAz26MkQIa5z4z3uOgZnGJB9pjv",  // staging 2
//            apiHost: "api-staging.youversion.com",
            appName: "Sample App",
            //isSignInEnabled: false,
            signInPromptMessage: "Sign in to see your YouVersion highlights in this Sample App."
        )
        YouVersionPlatformLogger.level = .debug
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
