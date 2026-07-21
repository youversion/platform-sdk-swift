import Foundation

public struct YouVersionPlatformConfiguration {
    nonisolated(unsafe) public private(set) static var appKey: String?
    nonisolated(unsafe) public private(set) static var apiHost = "api.youversion.com"

    /// The name of the host app, shown in sign-in dialogs.
    nonisolated(unsafe) public private(set) static var appName: String?

    /// A message explaining why the user should sign in, displayed on the sign-in sheet.
    nonisolated(unsafe) public private(set) static var signInPromptMessage: String?

    /// When `false`, all sign-in prompts and sign-in/sign-out UI are suppressed.
    /// Defaults to `true`.
    nonisolated(unsafe) public private(set) static var isSignInEnabled = true

    /// When set, only Bible versions whose `languageTag` is in this set are made available
    /// in the version picker UI and other version listings. When `nil` (the default), versions
    /// in all languages are available. Tags follow BCP 47 (e.g. `"en"` for English).
    nonisolated(unsafe) public private(set) static var permittedLanguageTags: Set<String>?

    /// When set, only Bible versions whose `id` is in this set are made available in the
    /// version picker UI and other version listings. When `nil` (the default), all versions
    /// are available. Combines with ``permittedLanguageTags`` — a version must satisfy both
    /// filters to be available.
    nonisolated(unsafe) public private(set) static var permittedVersionIds: Set<Int>?

    private static let installIdKey = "YouVersionPlatformInstallID"
    nonisolated(unsafe) public private(set) static var installId: String?

    private static let accessTokenKey = "YouVersionPlatformAccessToken"
    private static let refreshTokenKey = "YouVersionPlatformRefreshToken"
    private static let idTokenKey = "YouVersionPlatformIDToken"
    private static let expiryDateKey = "YouVersionPlatformExpiryDate"
    private static let permissionsKey = "YouVersionPlatformDataExchangePermissions"

    public static let authStateDidChangeNotification = Notification.Name("YouVersionPlatformAuthStateDidChange")

    @available(*, deprecated, message: "Use hasPermission(_:) instead.")
    static var permissionEnums: [SignInWithYouVersionPermission] {
        storedPermissions.compactMap { SignInWithYouVersionPermission(rawValue: $0) }
    }

    static var storedPermissions: [String] {
        UserDefaults.standard
            .stringArray(forKey: permissionsKey) ?? []
    }

    @MainActor
    public static func configure(
        appKey: String?,
        apiHost: String? = nil,
        appName: String? = nil,
        isSignInEnabled: Bool = true,
        signInPromptMessage: String? = nil,
        permittedLanguageTags: Set<String>? = nil,
        permittedVersionIds: Set<Int>? = nil
    ) {
        let defaults = UserDefaults.standard

        Self.appKey = appKey

        // Setting apiHost is really only for YVP development use:
        if let apiHost {
            Self.apiHost = apiHost
        }

        Self.appName = appName
        Self.isSignInEnabled = isSignInEnabled
        Self.signInPromptMessage = signInPromptMessage
        Self.permittedLanguageTags = permittedLanguageTags
        Self.permittedVersionIds = permittedVersionIds

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
    public static func configureSignIn(appName: String, signInPromptMessage: String? = nil) {
        Self.appName = appName
        Self.signInPromptMessage = signInPromptMessage
        Self.isSignInEnabled = true
    }

    @MainActor
    public static func saveAuthData(
        accessToken: String?,
        refreshToken: String?,
        idToken: String?,
        expiryDate: Date?,
        permissions: [String]? = nil
    ) {
        let previousAccessToken = Self.accessToken
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        UserDefaults.standard.set(idToken, forKey: idTokenKey)
        UserDefaults.standard.set(expiryDate, forKey: expiryDateKey)
        if let permissions {
            savePermissions(permissions)
        }
        postAuthStateDidChangeNotificationIfNeeded(previousAccessToken: previousAccessToken)
    }

    @MainActor
    public static func clearAuthTokens() {
        saveAuthData(accessToken: nil, refreshToken: nil, idToken: nil, expiryDate: nil)
        UserDefaults.standard.removeObject(forKey: permissionsKey)
    }

    public static var accessToken: String? {
        UserDefaults.standard.string(forKey: accessTokenKey)
    }

    public static var authData: SignInWithYouVersionResult? {
        guard let accessToken = UserDefaults.standard.string(forKey: accessTokenKey) else {
            return nil
        }

        let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
        let idToken = UserDefaults.standard.string(forKey: idTokenKey)
        let expiryDate = UserDefaults.standard.object(forKey: expiryDateKey) as? Date

        return SignInWithYouVersionResult(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            expiryDate: expiryDate,
            permissionValues: storedPermissions
        )
    }

    private static func savePermissions(_ permissions: [String]) {
        let rawValues = Set(storedPermissions + permissions)
            .sorted()
        UserDefaults.standard.set(rawValues, forKey: permissionsKey)
    }
    
    @available(*, deprecated, message: "Use hasPermission(_:) with a raw String permission value instead.")
    public static func hasPermission(_ permission: SignInWithYouVersionPermission) -> Bool {
        permissionEnums.contains(permission)
    }

    public static func hasPermission(_ permission: String) -> Bool {
        storedPermissions.contains(permission)
    }

    private static func postAuthStateDidChangeNotificationIfNeeded(previousAccessToken: String?) {
        guard previousAccessToken != accessToken else {
            return
        }
        NotificationCenter.default.post(name: authStateDidChangeNotification, object: nil)
    }

}

/// Convenience function to configure YouVersionPlatform. Run just once, in your app's initialization code. For example:
/// "import YouVersionPlatform; YouVersionPlatform.configure(appKey: ...)"
@MainActor
public func configure(appKey: String) {
    YouVersionPlatformConfiguration.configure(appKey: appKey)
}
