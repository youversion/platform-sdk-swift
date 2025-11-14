import Foundation

public struct YouVersionPlatformConfiguration {
    nonisolated(unsafe) public static var appKey: String?
    nonisolated(unsafe) public static var apiHost = "api.youversion.com"

    private static let installIdKey = "YouVersionPlatformInstallID"
    nonisolated(unsafe) public private(set) static var installId: String?

    private static let accessTokenKey = "YouVersionPlatformAccessToken"
    private static let refreshTokenKey = "YouVersionPlatformRefreshToken"
    private static let expiryDateKey = "YouVersionPlatformExpiryDate"

    @MainActor
    public static func configure(appKey: String?, apiHost: String? = nil) {
        let defaults = UserDefaults.standard

        if let appKey {
            Self.appKey = appKey
        }

        // Setting apiHost is really only for YVP development use:
        if let apiHost {
            Self.apiHost = apiHost
        }

        // Create and save an Install ID if it's not present
        if let existing = defaults.string(forKey: installIdKey) {
            Self.installId = existing
        } else {
            let newId = UUID().uuidString
            defaults.set(newId, forKey: installIdKey)
            Self.installId = newId
        }
    }

    @MainActor
    public static func saveAuthData(accessToken: String?, refreshToken: String?, expiryDate: Date?) {
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        UserDefaults.standard.set(expiryDate, forKey: expiryDateKey)
    }

    @MainActor
    public static func clearAuthTokens() {
        saveAuthData(accessToken: nil, refreshToken: nil, expiryDate: nil)
    }

    public static var accessToken: String? {
        UserDefaults.standard.string(forKey: accessTokenKey)
    }

    public static var refreshToken: String? {
        UserDefaults.standard.string(forKey: refreshTokenKey)
    }

    public static var tokenExpiryDate: Date? {
        UserDefaults.standard.object(forKey: expiryDateKey) as? Date
    }

}

/// Convenience function to configure YouVersionPlatform. Run just once, in your app's initialization code. For example:
/// "import YouVersionPlatform; YouVersionPlatform.configure(appKey: ...)"
@MainActor
public func configure(appKey: String) {
    YouVersionPlatformConfiguration.configure(appKey: appKey)
}
