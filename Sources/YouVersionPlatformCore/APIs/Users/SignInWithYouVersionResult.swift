import Foundation

public struct SignInWithYouVersionResult: Sendable {
    public let accessToken: String?
    public let expiryDate: Date?
    public let refreshToken: String?
    public let idToken: String?
    public let permissionValues: [String]
    public let yvpUserId: String?
    public let name: String?
    public let profilePicture: String?
    public let email: String?

    @available(*, deprecated, message: "Use permissionValues instead.")
    public var permissions: [SignInWithYouVersionPermission] {
        permissionValues.compactMap { SignInWithYouVersionPermission(rawValue: $0) }
    }

    public init(
        accessToken: String?,
        expiresIn: String?,
        refreshToken: String?,
        idToken: String?,
        permissionValues: [String],
        yvpUserId: String?,
        name: String? = nil,
        profilePicture: String? = nil,
        email: String? = nil
    ) {
        self.accessToken = accessToken
        let seconds = Int(expiresIn ?? "0") ?? 0
        self.expiryDate = Date(timeIntervalSinceNow: TimeInterval(seconds))
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.permissionValues = permissionValues
        self.yvpUserId = yvpUserId
        self.name = name
        self.profilePicture = profilePicture
        self.email = email
    }

    @available(*, deprecated, message: "Use init(accessToken:expiresIn:refreshToken:idToken:permissionValues:yvpUserId:name:profilePicture:email:) instead.")
    public init(accessToken: String?, expiresIn: String?, refreshToken: String?, idToken: String?, permissions: [SignInWithYouVersionPermission],
                yvpUserId: String?, name: String? = nil, profilePicture: String? = nil, email: String? = nil) {
        self.init(
            accessToken: accessToken,
            expiresIn: expiresIn,
            refreshToken: refreshToken,
            idToken: idToken,
            permissionValues: permissions.map(\.rawValue),
            yvpUserId: yvpUserId,
            name: name,
            profilePicture: profilePicture,
            email: email
        )
    }

    public init(
        accessToken: String?,
        refreshToken: String?,
        idToken: String?,
        expiryDate: Date?,
        permissionValues: [String] = []
    ) {
        self.accessToken = accessToken
        self.expiryDate = expiryDate
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.permissionValues = permissionValues
        self.yvpUserId = nil
        self.name = nil
        self.profilePicture = nil
        self.email = nil
    }

    @available(*, deprecated, message: "Use init(accessToken:refreshToken:idToken:expiryDate:permissionValues:) instead.")
    public init(
        accessToken: String?,
        refreshToken: String?,
        idToken: String?,
        expiryDate: Date?,
        permissions: [SignInWithYouVersionPermission] = []
    ) {
        self.init(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            expiryDate: expiryDate,
            permissionValues: permissions.map(\.rawValue)
        )
    }
}
