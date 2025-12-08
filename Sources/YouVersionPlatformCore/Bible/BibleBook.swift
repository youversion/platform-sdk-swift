import Foundation

public struct BibleBook: Codable, Sendable {
    public let id: String?
    public let title: String?
    public let fullTitle: String?
    public let abbreviation: String?
    public let canon: String?
    public let chapters: [BibleChapter]?

    enum CodingKeys: String, CodingKey {
        case id
        case title = "title"
        case fullTitle = "full_title"
        case abbreviation
        case canon
        case chapters
    }

    public var isCanonical: Bool {
        ["ot", "nt", "old_testament", "new_testament"].contains(canon)
    }

}
