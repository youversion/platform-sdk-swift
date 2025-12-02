import Foundation

public enum SignInWithYouVersionPermission: String, CaseIterable, Hashable, Codable, CustomStringConvertible, Sendable {
    case openid
    case profile
    case email

    public var description: String { rawValue }
}
