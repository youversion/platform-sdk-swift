import Foundation

public struct BibleChapter: Codable, Sendable {
    public let id: String?
    public let passageId: String?
    public let title: String?
    public let verses: [BibleVerse]?

    enum CodingKeys: String, CodingKey {
        case id
        case passageId = "passage_id"
        case title
        case verses
    }

}
