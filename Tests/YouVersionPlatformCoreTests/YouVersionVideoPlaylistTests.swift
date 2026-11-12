import Foundation
import Testing
import YouVersionPlatformCore

struct YouVersionVideoPlaylistTests {
    /// Supports descriptions from the new contract and older responses that omit the field.
    @Test(arguments: ["\"A playlist description.\"", "null", nil])
    func playlistDescriptionDecoding(descriptionJSON: String?) throws {
        let descriptionField = if let descriptionJSON { "\"description\":\(descriptionJSON)," } else { "" }
        let json = """
        {"id":4825,"title":"How To Read The Bible",\(descriptionField)
        "type":"VIDEOS","total":2,"videos":["video-b","video-a"]}
        """
        let playlist = try JSONDecoder().decode(YouVersionVideoPlaylist.self, from: Data(json.utf8))
        let collectionJSON = "{\"data\":[\(json)],\"next_page_token\":null}"
        let collection = try JSONDecoder().decode(YouVersionVideoPlaylistCollection.self, from: Data(collectionJSON.utf8))
        let expectedDescription = descriptionJSON == "\"A playlist description.\"" ? "A playlist description." : nil

        #expect(playlist.description == expectedDescription)
        #expect(collection.playlists == [playlist])
        #expect(collection.nextPageToken == nil)
        #expect(playlist.videoIDs == ["video-b", "video-a"])
        #expect(try JSONDecoder().decode(YouVersionVideoPlaylist.self, from: JSONEncoder().encode(playlist)) == playlist)
    }

    /// Rejects malformed descriptions rather than silently dropping metadata.
    @Test(arguments: ["42", "[]", "{}", "true"])
    func malformedPlaylistDescriptionIsRejected(descriptionJSON: String) throws {
        let json = """
        {"id":4825,"title":"How To Read The Bible","description":\(descriptionJSON),
        "type":"VIDEOS","total":0,"videos":[]}
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(YouVersionVideoPlaylist.self, from: Data(json.utf8))
        }
    }
}
