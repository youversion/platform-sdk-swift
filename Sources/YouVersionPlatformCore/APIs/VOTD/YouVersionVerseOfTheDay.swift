import Foundation

public struct YouVersionVerseOfTheDay: Codable, Sendable {
    public let passageId: String
    public let day: Int
    /// The opaque identifier of this day's verse art, or `nil` when no language ranges were requested or no art matches them.
    ///
    /// Resolve it with ``YouVersionAPI/Images/image(id:accessToken:session:)``. Image IDs are issued per response,
    /// so don't persist, compare, or reconstruct them.
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
