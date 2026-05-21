import Foundation

public enum DataExchangePermission: RawRepresentable, Hashable, Codable, CustomStringConvertible, Sendable {
    case highlights
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "highlights":
            self = .highlights
        default:
            self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .highlights:
            return "highlights"
        case .unknown(let rawValue):
            return rawValue
        }
    }

    public var description: String { rawValue }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = DataExchangePermission(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
