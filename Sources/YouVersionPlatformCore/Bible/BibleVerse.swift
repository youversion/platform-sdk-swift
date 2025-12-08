import Foundation

public struct BibleVerse: Codable, Sendable {
    public let id: String?
    public let passageId: String?
    public let title: String?

    enum CodingKeys: String, CodingKey {
        case id
        case passageId = "passage_id"
        case title
    }

}
