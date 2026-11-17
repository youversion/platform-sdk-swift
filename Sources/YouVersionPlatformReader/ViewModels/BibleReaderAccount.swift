import YouVersionPlatformCore

/// The identity that owns reader data, stable across token refreshes when the user is known.
struct BibleReaderAccount: Equatable {
    let userID: String?
    let appKey: String?
    let apiHost: String
    private let unidentifiedAccessToken: String?

    init(userID: String?, accessToken: String, appKey: String?, apiHost: String) {
        self.userID = userID
        self.appKey = appKey
        self.apiHost = apiHost
        unidentifiedAccessToken = userID == nil ? accessToken : nil
    }

    static var current: Self? {
        guard let accessToken = YouVersionPlatformConfiguration.accessToken else {
            return nil
        }
        return Self(
            userID: YouVersionAPI.Users.currentUserId,
            accessToken: accessToken,
            appKey: YouVersionPlatformConfiguration.appKey,
            apiHost: YouVersionPlatformConfiguration.apiHost
        )
    }
}
