import YouVersionPlatformCore

/// The owner and API environment of locally retained Notes data.
struct BibleNotesAccount: Equatable {
    let userID: String?
    let appKey: String?
    let apiHost: String

    @MainActor
    static var signedIn: Self {
        Self(
            userID: YouVersionAPI.Users.currentUserId,
            appKey: YouVersionPlatformConfiguration.appKey,
            apiHost: YouVersionPlatformConfiguration.apiHost
        )
    }
}
