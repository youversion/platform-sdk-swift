import Foundation

@available(*, deprecated, message: "Use raw String permission values instead.")
public enum SignInWithYouVersionPermission: RawRepresentable, CaseIterable, Hashable, Codable, CustomStringConvertible, Sendable {
    case openid
    case profile
    case email

    public static let allCases: [SignInWithYouVersionPermission] = [
        .openid,
        .profile,
        .email
    ]

    public init?(rawValue: String) {
        switch rawValue {
        case "openid":
            self = .openid
        case "profile":
            self = .profile
        case "email":
            self = .email
        default:
            return nil
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
        }
    }

    public var description: String { rawValue }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let permission = SignInWithYouVersionPermission(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown permission value: \(rawValue)"
            )
        }
        self = permission
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
