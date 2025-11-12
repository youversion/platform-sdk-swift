import Foundation

public enum SignInWithYouVersionPermission: String, CaseIterable, Hashable, Codable, CustomStringConvertible, Sendable {
    case bibles
    case highlights
    case votd
    case demographics
    case bibleActivity = "bible_activity"

    public var description: String { rawValue }
}
