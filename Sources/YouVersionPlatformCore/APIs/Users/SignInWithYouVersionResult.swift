import Foundation

public struct SignInWithYouVersionResult: Sendable {
    public let accessToken: String?
    public let expiryDate: Date?
    public let refreshToken: String?
    public let idToken: String?
    public let permissions: [SignInWithYouVersionPermission]
    public let yvpUserId: String?
    public let name: String?
    public let profilePicture: String?
    public let email: String?

    public init(accessToken: String?, expiresIn: String?, refreshToken: String?, idToken: String?, permissions: [SignInWithYouVersionPermission],
                yvpUserId: String?, name: String? = nil, profilePicture: String? = nil, email: String? = nil) {
        self.accessToken = accessToken
        let seconds = Int(expiresIn ?? "0") ?? 0
        self.expiryDate = Date(timeIntervalSinceNow: TimeInterval(seconds))
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.permissions = permissions
        self.yvpUserId = yvpUserId
        self.name = name
        self.profilePicture = profilePicture
        self.email = email
    }
    public init(accessToken: String?, refreshToken: String?, idToken: String?, expiryDate: Date?) {
        self.accessToken = accessToken
        self.expiryDate = expiryDate
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.permissions = []
        self.yvpUserId = nil
        self.name = nil
        self.profilePicture = nil
        self.email = nil
    }
}
