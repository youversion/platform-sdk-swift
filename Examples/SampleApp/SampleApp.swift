import SwiftUI
import YouVersionPlatform

@main
struct SampleApp: App {

    @State private var selectedTab = 0
    @State private var readerNavigation = BibleReaderNavigation()

    init() {
        // Get your app key from https://platform.youversion.com/
        YouVersionPlatformConfiguration.configure(
            appKey: "<#Your App Key#>", // prod SampleApp
            appName: String(localized: "app.name"),
            signInPromptMessage: String(localized: "app.sign_in_prompt")
        )
    }

    var body: some Scene {
        WindowGroup {
            let reader = BibleReaderView.restoringLastPassage(readerNavigation: readerNavigation)
                .navigationPlacement(ProcessInfo.processInfo.arguments.contains("--reader-top") ? .topBar : .bottomBar)
            Group {
                if ProcessInfo.processInfo.arguments.contains("--reader-no-tabs") {
                    reader
                } else {
                    TabView(selection: $selectedTab) {
                        reader
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
#if DEBUG
            .overlay {
                if ProcessInfo.processInfo.arguments.contains("--reader-width-debug") {
                    GeometryReader { geometry in
                        Text(verbatim: String(format: "Width: %.2f pt", geometry.size.width))
                            .font(.caption.monospacedDigit())
                            .padding(8)
                            .foregroundStyle(.white)
                            .background(.black.opacity(0.8), in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
#endif
        }
    }
}
