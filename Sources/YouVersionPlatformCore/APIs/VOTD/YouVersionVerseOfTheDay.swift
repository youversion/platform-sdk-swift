import Foundation

public struct YouVersionVerseOfTheDay: Codable, Sendable {
    public let passageId: String
    public let day: Int
    public let imageID: String?

    enum CodingKeys: String, CodingKey {
        case passageId = "passage_id"
        case day
        case imageID = "image_id"
    }
    
    public init(
        passageId: String,
        day: Int
    ) {
        self.passageId = passageId
        self.day = day
        self.imageID = nil
    }
    
    public static var preview: YouVersionVerseOfTheDay {
        YouVersionVerseOfTheDay(
            passageId: "JHN.1.1",
            day: 1
        )
    }
}
