import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import YouVersionPlatformCore

struct VideosAPITests {
    private let videoJSON = """
    {"id":"opaque.video-id","title":"What Is The Bible?","description":"A video description.",
    "references":["GEN.1","EXO.20.1+EXO.20.2"],"language_tag":"en","runtime":315,"orientation":"landscape",
    "thumbnail":{"url":"https://images.example.com/{width}x{height}/image.jpg?token=opaque","width":1280,"height":720},
    "playback_sources":[{"url":"https://cdn.example.com/video.m3u8?token=opaque","format":"hls"}],
    "playback_preview_sources":[{"url":"https://cdn.example.com/preview.mp4","format":"mp4"}],
    "share_url":"https://www.bible.com/en/videos/25439"}
    """

    @Test func playlistPagePreservesOrderPaginationAndRequestHeaders() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let organizationID = "organization/id ?#"
        let pageToken = "a+b/c==&?% fragment"
        let json = Data("""
        {"data":[{"id":4825,"title":"How To Read The Bible","type":"VIDEOS","total":2,"videos":["video-b","video-a"]}],
        "next_page_token":"next+opaque/="}
        """.utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(request.httpMethod == "GET")
            #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer video-tests")
            #expect(components.path == "/v1/organizations/\(organizationID)/playlists")
            #expect(components.percentEncodedPath.contains("organization%2Fid%20%3F%23"))
            #expect(components.queryItems == [URLQueryItem(name: "page_size", value: "50"), URLQueryItem(name: "page_token", value: pageToken)])
            #expect(components.percentEncodedQuery?.contains("a%2Bb") == true)
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Videos.playlists(
            organizationID: organizationID, pageSize: 50, pageToken: pageToken, accessToken: "video-tests", session: session
        )
        let playlist = try #require(page.playlists.first)
        #expect(playlist.title == "How To Read The Bible")
        #expect(playlist.type == "VIDEOS")
        #expect(playlist.id == 4825)
        #expect(playlist.videoIDs == ["video-b", "video-a"])
        #expect(playlist.total == 2)
        #expect(page.nextPageToken == "next+opaque/=")
    }

    @Test func explicitInitialCursorIsPreserved() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.queryItems?.contains(URLQueryItem(name: "page_token", value: "")) == true)
            #expect(components.percentEncodedQuery?.hasSuffix("page_token=") == true)
            return (Data("{\"data\":[]}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Videos.playlists(organizationID: "org", pageSize: 99, pageToken: "", session: session)
        #expect(page.playlists.isEmpty)
    }

    @Test func playlistResourceUsesOrganizationContextAndRequestHeaders() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let organizationID = "550e8400-e29b-41d4-a716-446655440000"
        let json = Data("""
        {"id":3669,"title":"Teaching Clips","type":"TEACHING_CLIPS","total":39,"videos":["52186","51575"]}
        """.utf8)
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/v1/organizations/\(organizationID)/playlists/3669")
            #expect(request.url?.query == nil)
            #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer playlist-tests")
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let playlist = try await YouVersionAPI.Videos.playlist(
            organizationID: organizationID, id: 3669, accessToken: "playlist-tests", session: session
        )
        #expect(playlist.id == 3669)
        #expect(playlist.title == "Teaching Clips")
        #expect(playlist.type == "TEACHING_CLIPS")
        #expect(playlist.total == 39)
        #expect(playlist.videoIDs == ["52186", "51575"])
        #expect(try JSONDecoder().decode(YouVersionVideoPlaylist.self, from: JSONEncoder().encode(playlist)) == playlist)
    }

    @Test(arguments: [1, 99, nil])
    func playlistPageSizeBoundariesAndServerDefault(pageSize: Int?) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            if let pageSize {
                #expect(components.queryItems == [URLQueryItem(name: "page_size", value: String(pageSize))])
            } else {
                #expect(components.queryItems == nil)
            }
            return (Data("{\"data\":[]}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Videos.playlists(organizationID: "org", pageSize: pageSize, session: session)
        #expect(page.playlists.isEmpty)
        #expect(page.nextPageToken == nil)
    }

    @Test(arguments: ["id", "title", "type", "total", "videos"])
    func requiredPlaylistFieldsCannotBeMissingOrNull(field: String) throws {
        let original: [String: Any] = ["id": 3669, "title": "Teaching Clips", "type": "TEACHING_CLIPS", "total": 0, "videos": []]
        var missing = original
        missing.removeValue(forKey: field)
        let missingData = try JSONSerialization.data(withJSONObject: missing)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionVideoPlaylist.self, from: missingData) }
        var null = original
        null[field] = NSNull()
        let nullData = try JSONSerialization.data(withJSONObject: null)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionVideoPlaylist.self, from: nullData) }
    }

    @Test func videoPreservesOpaqueIDMetadataAndPlaybackURLs() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let id = "opaque/id+?%# fragment"
        let data = Data(videoJSON.utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
            let prefix = "/v1/videos/"
            #expect(components.percentEncodedPath.hasPrefix(prefix))
            let segment = String(components.percentEncodedPath.dropFirst(prefix.count))
            #expect(!segment.contains("/"))
            #expect(segment.removingPercentEncoding == id)
            #expect(components.query == nil)
            #expect(components.fragment == nil)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let video = try await YouVersionAPI.Videos.video(id: id, accessToken: "video-tests", session: session)
        #expect(video.runtime == 315)
        #expect(video.references == ["GEN.1", "EXO.20.1+EXO.20.2"])
        #expect(video.languageTag == "en")
        #expect(video.playbackSources.first?.url.query == "token=opaque")
        #expect(video.playbackSources.first?.format == "hls")
        #expect(video.playbackPreviewSources.first?.format == "mp4")
        #expect(video.shareURL?.absoluteString == "https://www.bible.com/en/videos/25439")
        let thumbnail = try #require(video.thumbnail)
        #expect(abs(try #require(thumbnail.aspectRatio) - 16.0 / 9) < 0.0001)
        #expect(thumbnail.url(width: 300, height: 168)?.absoluteString
            == "https://images.example.com/300x168/image.jpg?token=opaque")
        #expect(thumbnail.url(width: 0, height: 168) == nil)
        let roundTrip = try JSONDecoder().decode(YouVersionVideo.self, from: JSONEncoder().encode(video))
        #expect(roundTrip == video)
    }

    @Test func videoAllowsNullReferences() throws {
        let json = videoJSON.replacingOccurrences(of: "[\"GEN.1\",\"EXO.20.1+EXO.20.2\"]", with: "null")
        #expect(try JSONDecoder().decode(YouVersionVideo.self, from: Data(json.utf8)).references == nil)
    }

    @Test(arguments: [false, true])
    func nullableMetadataCanBeAbsentOrNull(explicitNulls: Bool) throws {
        var object: [String: Any] = ["id": "latest-id", "playback_sources": [], "playback_preview_sources": []]
        if explicitNulls {
            for key in ["title", "description", "references", "language_tag", "runtime", "orientation", "thumbnail", "share_url"] {
                object[key] = NSNull()
            }
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        let video = try JSONDecoder().decode(YouVersionVideo.self, from: data)
        #expect(video.id == "latest-id")
        #expect(video.title == nil)
        #expect(video.description == nil)
        #expect(video.references == nil)
        #expect(video.languageTag == nil)
        #expect(video.runtime == nil)
        #expect(video.orientation == nil)
        #expect(video.thumbnail == nil)
        #expect(video.shareURL == nil)
        #expect(video.playbackSources.isEmpty)
        #expect(video.playbackPreviewSources.isEmpty)
    }

    @Test(arguments: ["{}", "{\"url\":null,\"width\":null,\"height\":null}", "{\"width\":640}",
                      "{\"width\":640,\"height\":0}", "{\"width\":-1,\"height\":360}"])
    func incompleteThumbnailHasNoInventedDimensions(json: String) throws {
        let thumbnail = try JSONDecoder().decode(YouVersionVideo.Thumbnail.self, from: Data(json.utf8))
        #expect(thumbnail.aspectRatio == nil)
        #expect(thumbnail.url(width: 300, height: 168) == nil)
    }

    @Test func concreteThumbnailURLNeedsNoTemplateOrNativeDimensions() throws {
        let thumbnail = try JSONDecoder().decode(YouVersionVideo.Thumbnail.self, from: Data("""
        {"url":"https://images.example.com/image.jpg?token=opaque"}
        """.utf8))
        #expect(thumbnail.url(width: 300, height: 168)?.absoluteString == "https://images.example.com/image.jpg?token=opaque")
        #expect(thumbnail.aspectRatio == nil)
    }

    @Test(arguments: ["id", "playback_sources", "playback_preview_sources"])
    func requiredFieldsCannotBeMissingOrNull(field: String) throws {
        let original = try #require(JSONSerialization.jsonObject(with: Data(videoJSON.utf8)) as? [String: Any])
        var missing = original
        missing.removeValue(forKey: field)
        let missingData = try JSONSerialization.data(withJSONObject: missing)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionVideo.self, from: missingData) }
        var null = original
        null[field] = NSNull()
        let nullData = try JSONSerialization.data(withJSONObject: null)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionVideo.self, from: nullData) }
    }

    @Test(arguments: ["hls", "webm", "mp4", "mp3"])
    func documentedSourceFormatsArePreserved(format: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["url": "https://cdn.example.com/asset", "format": format])
        let source = try JSONDecoder().decode(YouVersionVideo.PlaybackSource.self, from: data)
        #expect(source.format == format)
    }

    @Test(arguments: ["url", "format"])
    func playbackSourcesRequireURLAndFormat(field: String) throws {
        var object = ["url": "https://cdn.example.com/asset", "format": "hls"]
        object.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionVideo.PlaybackSource.self, from: data) }
    }

    @Test func runtimeIsAnIntegerNumberOfSeconds() throws {
        let json = videoJSON.replacingOccurrences(of: "\"runtime\":315", with: "\"runtime\":315.5")
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionVideo.self, from: Data(json.utf8)) }
    }

    @Test func subsequentRequestsUseTheLatestResponseIdentifier() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let originalData = Data(videoJSON.utf8)
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.url?.path == "/v1/videos/52186")
            return (originalData, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let first = try await YouVersionAPI.Videos.video(id: "52186", session: session)
        #expect(first.id == "opaque.video-id")
        let updatedData = Data(videoJSON.replacingOccurrences(of: "opaque.video-id", with: "next-response-id").utf8)
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.url?.path == "/v1/videos/opaque.video-id")
            return (updatedData, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let second = try await YouVersionAPI.Videos.video(id: first.id, session: session)
        #expect(second.id == "next-response-id")
    }

    @Test func noContentReturnsEmptyPlaylistPage() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Videos.playlists(organizationID: "org", session: session)
        #expect(page.playlists.isEmpty)
        #expect(page.nextPageToken == nil)
    }

    @Test(arguments: [401, 403, 404, 500])
    func httpFailuresPropagate(status: Int) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        let expected: YouVersionAPIError = status == 401 || status == 403 ? .notPermitted : .cannotDownload
        await #expect(throws: expected) { try await YouVersionAPI.Videos.video(id: "video", session: session) }
        await #expect(throws: expected) { try await YouVersionAPI.Videos.playlists(organizationID: "org", session: session) }
        await #expect(throws: expected) { try await YouVersionAPI.Videos.playlist(organizationID: "org", id: 3669, session: session) }
    }

    @Test func emptyIdentifiersFailBeforeNetworking() async {
        await #expect {
            try await YouVersionAPI.Videos.playlist(organizationID: "", id: 3669)
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
        await #expect {
            try await YouVersionAPI.Videos.video(id: "")
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
        await #expect {
            try await YouVersionAPI.Videos.playlists(organizationID: "")
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
    }

    @Test(arguments: [0, -1, 100, Int.max])
    func invalidPageSizesFailBeforeNetworking(pageSize: Int) async {
        await #expect {
            try await YouVersionAPI.Videos.playlists(organizationID: "org", pageSize: pageSize)
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
    }

    @Test func temporaryLanguageOverrideWinsOverSessionPreferences() async throws {
        let (baseSession, token) = HTTPMocking.makeSession()
        let configuration = baseSession.configuration
        var headers = configuration.httpAdditionalHeaders ?? [:]
        headers["Accept-Language"] = "en-US,en;q=0.9"
        configuration.httpAdditionalHeaders = headers
        let session = URLSession(configuration: configuration)
        defer {
            HTTPMocking.clear(token: token)
            session.invalidateAndCancel()
            baseSession.invalidateAndCancel()
        }
        let videoData = Data(videoJSON.utf8)
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
            let data = request.url!.path.hasPrefix("/v1/videos/") ? videoData : Data("{\"data\":[]}".utf8)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        _ = try await YouVersionAPI.Videos.playlists(organizationID: "org", session: session)
        _ = try await YouVersionAPI.Videos.video(id: "video", session: session)
    }

    @Test func malformedMetadataIsNotReportedAsAnEmptyCollection() async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await #expect(throws: DecodingError.self) { try await YouVersionAPI.Videos.video(id: "video", session: session) }
        await #expect(throws: DecodingError.self) {
            try await YouVersionAPI.Videos.playlists(organizationID: "org", session: session)
        }
    }
}
