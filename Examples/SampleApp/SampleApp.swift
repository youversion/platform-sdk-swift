import SwiftUI
import UIKit
import YouVersionPlatform

@main
struct SampleApp: App {

    @State private var selectedTab = 0
    @State private var readerNavigation = BibleReaderNavigation()

    init() {
        let tabColor = UIColor(red: 242.0 / 255, green: 59.0 / 255, blue: 34.0 / 255, alpha: 1)
        let tabAppearance = UITabBarAppearance()
        for itemAppearance in [
            tabAppearance.stackedLayoutAppearance,
            tabAppearance.inlineLayoutAppearance,
            tabAppearance.compactInlineLayoutAppearance
        ] {
            itemAppearance.selected.iconColor = tabColor
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: tabColor]
        }
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

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
                    Label {
                        Text("tab.bible")
                    } icon: {
                        Image(selectedTab == 0 ? "bible_filled" : "bible_stroked")
                            .renderingMode(.template)
                    }
                }
                .tag(0)

                ContentView(navigation: readerNavigation, onNavigate: { selectedTab = 0 })
                    .tabItem {
                        Label("Content", image: "box-video-stack_stroked")
                    }
                    .tag(1)

                ExamplesView(navigation: readerNavigation, onNavigate: { selectedTab = 0 })
                    .tabItem {
                        Label("Examples", systemImage: "square.grid.2x2")
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
