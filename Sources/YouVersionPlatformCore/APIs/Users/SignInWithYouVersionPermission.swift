import Foundation

public enum SignInWithYouVersionPermission: RawRepresentable, CaseIterable, Hashable, Codable, CustomStringConvertible, Sendable {
    case openid
    case profile
    case email
    case highlights
    case unknown(String)

    public static let allCases: [SignInWithYouVersionPermission] = [
        .openid,
        .profile,
        .email,
        .highlights
    ]

    /// Creates a permission from a raw permission value, preserving unrecognized values as ``unknown(_:)``.
    public init(rawValue: String) {
        switch rawValue {
        case "openid":
            self = .openid
        case "profile":
            self = .profile
        case "email":
            self = .email
        case "highlights":
            self = .highlights
        default:
            self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .openid:
            return "openid"
        case .profile:
            return "profile"
        case .email:
            return "email"
        case .highlights:
            return "highlights"
        case .unknown(let rawValue):
            return rawValue
        }
    }

    public var description: String { rawValue }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = SignInWithYouVersionPermission(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension SignInWithYouVersionPermission {
    var isAuthorizationScope: Bool {
        switch self {
        case .openid, .profile, .email:
            return true
        case .highlights, .unknown:
            return false
        }
    }
}
