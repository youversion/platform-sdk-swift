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
                Tab("Bible", systemImage: "book.closed.fill", value: 0) {
                    BibleReaderView()
                }
                .accessibilityIdentifier("sampleApp.tab.bible")

                Tab("VOTD", systemImage: "sun.max.fill", value: 1) {
                    VotdContainerView()
                }
                .accessibilityIdentifier("sampleApp.tab.verseOfTheDay")

                Tab("Card", systemImage: "doc.plaintext", value: 2) {
                    CardView()
                }
                .accessibilityIdentifier("sampleApp.tab.card")

                Tab("Profile", systemImage: "person.fill", value: 3) {
                    ProfileView()
                }
                .accessibilityIdentifier("sampleApp.tab.profile")
            }
        }
    }
}
