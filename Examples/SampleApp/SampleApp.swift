import SwiftUI
import YouVersionPlatform

@main
struct SampleApp: App {

    @State private var selectedTab = 0

    init() {
        YouVersionPlatform.configure(appKey: <#Your App Key#>)
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                BibleReaderView(appName: "Sample App", signInMessage: "Sign in to see your YouVersion highlights in this Sample App.")
                    .tabItem {
                        Label("Bible", systemImage: "book.closed.fill")
                    }
                    .tag(0)

                VotdContainerView()
                    .tabItem {
                        Label("VOTD", systemImage: "sun.max.fill")
                    }
                    .tag(1)

                WidgetView()
                    .tabItem {
                        Label("Widget", systemImage: "doc.plaintext")
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
