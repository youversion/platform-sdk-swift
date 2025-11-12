import Foundation

public struct YouVersionPlatformConfiguration {
    nonisolated(unsafe) public static var appKey: String?
    nonisolated(unsafe) public static var apiHost = "api.youversion.com"
    nonisolated(unsafe) public static var hostEnv: String?
    private static let installIdKey = "YouVersionPlatformInstallID"
    nonisolated(unsafe) public private(set) static var installId: String?
    private static let accessTokenKey = "YouVersionPlatformAccessToken"
    nonisolated(unsafe) public private(set) static var accessToken: String?

    @MainActor
    public static func configure(appKey: String?, accessToken: String? = nil, apiHost: String? = nil, hostEnv: String? = nil) {
        let defaults = UserDefaults.standard

        if let appKey {
            Self.appKey = appKey
        }

        if let accessToken {
            Self.accessToken = accessToken
        } else if let savedToken = defaults.string(forKey: accessTokenKey) {
            Self.accessToken = savedToken
        }

        // These are really only for YVP development use:
        if let apiHost {
            Self.apiHost = apiHost
        }
        if let hostEnv {
            Self.hostEnv = hostEnv
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
    public static func setAccessToken(_ accessToken: String?, saveToDefaults: Bool = true) {
        Self.accessToken = accessToken
        if saveToDefaults {
            UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        }
    }

}

/// Convenience function to configure YouVersionPlatform. Run just once, in your app's initialization code. For example:
/// "import YouVersionPlatform; YouVersionPlatform.configure(appKey: ...)"
@MainActor
public func configure(appKey: String?, accessToken: String? = nil) {
    YouVersionPlatformConfiguration.configure(
        appKey: appKey,
        accessToken: accessToken
    )
}
