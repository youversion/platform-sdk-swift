import Foundation

public struct BibleChapter: Codable, Sendable {
    //let id: String?  // This isn't what you want to use.
    public let bookUSFM: String?
    public let isCanonical: Bool?
    public let passageId: String?
    public let title: String?

    enum CodingKeys: String, CodingKey {
        case bookUSFM = "book_id"
        case isCanonical = "canonical"
        case passageId = "passage_id"
        case title
    }
}
