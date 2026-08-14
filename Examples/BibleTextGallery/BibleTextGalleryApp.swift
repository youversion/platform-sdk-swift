import SwiftUI
import YouVersionPlatform

@main
struct BibleTextGalleryApp: App {

    init() {
        // Get your app key from https://platform.youversion.com/
        YouVersionPlatformConfiguration.configure(
            appKey: "<#Your App Key#>",
            appName: "BibleText Gallery",
            isSignInEnabled: false
        )
    }

    var body: some Scene {
        WindowGroup {
            BibleTextGalleryView()
        }
    }
}
