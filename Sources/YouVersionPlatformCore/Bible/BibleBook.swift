import Foundation

public struct BibleBook: Codable, Sendable {
    public let usfm: String?
    public let abbreviation: String?
    public let title: String?
    public let titleLong: String?
    public let chapters: [BibleChapter]?

    enum CodingKeys: String, CodingKey {
        case usfm, abbreviation, chapters
        case title = "human"
        case titleLong = "human_long"
    }
}
