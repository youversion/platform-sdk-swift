import Foundation

public struct BibleChapter: Codable, Sendable {
    //let id: String?  // This isn't what you want to use.
    let bookUSFM: String?
    let isCanonical: Bool?
    let passageId: String?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case bookUSFM = "book_id"
        case isCanonical = "canonical"
        case passageId = "passage_id"
        case title
    }
}
