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
                NavigationStack {
                    BibleReaderView.restoringLastPassage(readerNavigation: readerNavigation)
                        .usingNavigationStack(.justForReader)
                        .navigationPlacement(.topBar)
                }
                .tabItem {
                    Label("tab.bible", systemImage: "book.closed.fill")
                }
                .tag(0)

                ContentLibraryView()
                    .tabItem {
                        Label("Content Library", systemImage: "play.rectangle.fill")
                    }
                    .tag(1)

                ProfileView()
                    .tabItem {
                        Label("tab.profile", systemImage: "person.fill")
                    }
                    .tag(4)

                MoreView(navigation: readerNavigation, onNavigate: { selectedTab = 0 })
                    .tabItem {
                        Label("More", systemImage: "ellipsis")
                    }
                    .tag(3)
            }
        }
    }
}
