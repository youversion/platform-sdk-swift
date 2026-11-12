import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import YouVersionPlatformCore

extension ConfigurationStateTests {
    @Suite(.serialized)
    struct VideosAPITests {
        private let videoJSON = """
        {"id":"opaque.video-id","title":"What Is The Bible?","description":"A video description.",
        "references":["GEN.1","EXO.20.1+EXO.20.2"],"language_tag":"en","runtime":315,"orientation":"landscape",
        "thumbnail":{"url":"https://cdn.example.com/video-images/image.jpg","width":1280,"height":720},
        "playback_sources":[{"url":"https://cdn.example.com/video.m3u8?token=opaque","format":"hls"}],
        "playback_preview_sources":[{"url":"https://cdn.example.com/preview.mp4","format":"mp4"}],
        "share_url":"https://www.bible.com/en/videos/25439"}
        """
    }
}

extension ConfigurationStateTests.VideosAPITests {
    /// Verifies playlist order, opaque pagination tokens, and configured request headers.
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
            #expect(request.cachePolicy == .useProtocolCachePolicy)
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
            organizationID: organizationID, pageSize: "50", pageToken: pageToken, accessToken: "video-tests", session: session
        )
        let playlist = try #require(page.playlists.first)
        #expect(playlist.title == "How To Read The Bible")
        #expect(playlist.type == "VIDEOS")
        #expect(playlist.id == 4825)
        #expect(playlist.videoIDs == ["video-b", "video-a"])
        #expect(playlist.total == 2)
        #expect(page.nextPageToken == "next+opaque/=")
    }

    /// Preserves an explicitly empty continuation token instead of omitting it.
    @Test func explicitInitialCursorIsPreserved() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.queryItems?.contains(URLQueryItem(name: "page_token", value: "")) == true)
            #expect(components.percentEncodedQuery?.hasSuffix("page_token=") == true)
            return (Data("{\"data\":[]}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Videos.playlists(organizationID: "org", pageSize: "99", pageToken: "", session: session)
        #expect(page.playlists.isEmpty)
    }

    /// Requests a single playlist within its organization and decodes its metadata.
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
            #expect(request.cachePolicy == .useProtocolCachePolicy)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == nil)
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

    /// Accepts the documented page-size boundaries and omits the server default.
    @Test(arguments: ["1", "99", nil])
    func playlistPageSizeBoundariesAndServerDefault(pageSize: String?) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            if let pageSize {
                #expect(components.queryItems == [URLQueryItem(name: "page_size", value: pageSize)])
            } else {
                #expect(components.queryItems == nil)
            }
            return (Data("{\"data\":[]}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Videos.playlists(organizationID: "org", pageSize: pageSize, session: session)
        #expect(page.playlists.isEmpty)
        #expect(page.nextPageToken == nil)
    }

    /// Allows field selection to omit any playlist property or return a null value.
    @Test(arguments: ["id", "title", "type", "total", "videos"])
    func playlistFieldsCanBeMissingOrNull(field: String) throws {
        let original: [String: Any] = ["id": 3669, "title": "Teaching Clips", "type": "TEACHING_CLIPS", "total": 0, "videos": []]
        var missing = original
        missing.removeValue(forKey: field)
        var null = original
        null[field] = NSNull()
        let missingPlaylist = try JSONDecoder().decode(YouVersionVideoPlaylist.self, from: JSONSerialization.data(withJSONObject: missing))
        let nullPlaylist = try JSONDecoder().decode(YouVersionVideoPlaylist.self, from: JSONSerialization.data(withJSONObject: null))
        #expect(missingPlaylist == nullPlaylist)
    }

    /// Preserves video metadata, opaque IDs, and playback and thumbnail URLs.
    @MainActor
    @Test func videoPreservesOpaqueIDMetadataAndPlaybackURLs() async throws {
        let originalAppKey = YouVersionPlatformConfiguration.appKey
        YouVersionPlatformConfiguration.configure(appKey: "thumbnail-tests")
        defer { YouVersionPlatformConfiguration.configure(appKey: originalAppKey) }
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let id = "opaque/id+?%# fragment"
        let data = Data(videoJSON.utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(request.cachePolicy == .useProtocolCachePolicy)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == nil)
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
        let thumbnailURL = try #require(thumbnail.url)
        #expect(thumbnailURL.host == "cdn.example.com")
        #expect(thumbnailURL.path == "/video-images/image.jpg")
        #expect(URLComponents(url: thumbnailURL, resolvingAgainstBaseURL: false)?.queryItems
            == [URLQueryItem(name: "app_key", value: "thumbnail-tests")])
        let roundTrip = try JSONDecoder().decode(YouVersionVideo.self, from: JSONEncoder().encode(video))
        #expect(roundTrip == video)
    }

    /// Returns ready-to-use thumbnails while preserving unrelated encoded query parameters.
    @MainActor
    @Test(arguments: ["thumb", "card", "full", nil])
    func videoConfiguresThumbnailURL(size: String?) async throws {
        let originalAppKey = YouVersionPlatformConfiguration.appKey
        let appKey = "thumbnail+key&=/"
        YouVersionPlatformConfiguration.configure(appKey: appKey)
        defer { YouVersionPlatformConfiguration.configure(appKey: originalAppKey) }
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let thumbnailURL = "https://cdn.example.com/video-images/image.jpg?token=a%2Bb%2Fc%3D&app_key=old&size=full&app_key=older&size=card#image"
        let data = Data(videoJSON.replacingOccurrences(
            of: "https://cdn.example.com/video-images/image.jpg", with: thumbnailURL
        ).utf8)
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.url?.query == nil)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let video = try await YouVersionAPI.Videos.video(id: "video", size: size, accessToken: "test", session: session)
        let url = try #require(video.thumbnail?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.percentEncodedQuery?.hasPrefix("token=a%2Bb%2Fc%3D&") == true)
        #expect(components.fragment == "image")
        #expect(components.queryItems?.filter { $0.name == "app_key" } == [URLQueryItem(name: "app_key", value: appKey)])
        let sizeItems = components.queryItems?.filter { $0.name == "size" } ?? []
        if let size {
            #expect(sizeItems == [URLQueryItem(name: "size", value: size)])
        } else {
            #expect(sizeItems.isEmpty)
        }
        #expect(video.playbackSources.first?.url.query == "token=opaque")
    }

    /// Rejects unsupported thumbnail sizes before networking.
    @Test(arguments: ["", "small", "THUMB"])
    func invalidThumbnailSizesFailBeforeNetworking(size: String) async {
        await #expect {
            try await YouVersionAPI.Videos.video(id: "video", size: size)
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
    }

    /// Requires an app key only when the response contains a thumbnail URL to authenticate.
    @MainActor
    @Test(arguments: [true, false])
    func thumbnailAuthenticationRequiresConfiguredAppKey(hasThumbnail: Bool) async throws {
        let originalAppKey = YouVersionPlatformConfiguration.appKey
        YouVersionPlatformConfiguration.configure(appKey: nil)
        defer { YouVersionPlatformConfiguration.configure(appKey: originalAppKey) }
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let data = Data((hasThumbnail ? videoJSON : "{\"id\":\"video\",\"playback_sources\":[],\"playback_preview_sources\":[]}").utf8)
        HTTPMocking.setHandler(token: token) { request in
            (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        if hasThumbnail {
            await #expect(throws: YouVersionAPIError.missingAuthentication) {
                try await YouVersionAPI.Videos.video(id: "video", accessToken: "test", session: session)
            }
        } else {
            let video = try await YouVersionAPI.Videos.video(id: "video", accessToken: "test", session: session)
            #expect(video.thumbnail == nil)
        }
    }

    /// Allows nullable scripture references in video metadata.
    @Test func videoAllowsNullReferences() throws {
        let json = videoJSON.replacingOccurrences(of: "[\"GEN.1\",\"EXO.20.1+EXO.20.2\"]", with: "null")
        #expect(try JSONDecoder().decode(YouVersionVideo.self, from: Data(json.utf8)).references == nil)
    }

    /// Decodes optional video metadata whether absent or explicitly null.
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

    /// Avoids deriving dimensions or URLs from incomplete thumbnail metadata.
    @Test(arguments: ["{}", "{\"url\":null,\"width\":null,\"height\":null}", "{\"width\":640}",
                      "{\"width\":640,\"height\":0}", "{\"width\":-1,\"height\":360}"])
    func incompleteThumbnailHasNoInventedDimensions(json: String) throws {
        let thumbnail = try JSONDecoder().decode(YouVersionVideo.Thumbnail.self, from: Data(json.utf8))
        #expect(thumbnail.aspectRatio == nil)
        #expect(thumbnail.url == nil)
    }

    /// Preserves a supplied thumbnail URL even when native dimensions are absent.
    @Test func thumbnailURLDoesNotRequireNativeDimensions() throws {
        let thumbnail = try JSONDecoder().decode(YouVersionVideo.Thumbnail.self, from: Data("""
        {"url":"https://images.example.com/image.jpg?token=opaque"}
        """.utf8))
        #expect(thumbnail.url?.absoluteString == "https://images.example.com/image.jpg?token=opaque")
        #expect(thumbnail.aspectRatio == nil)
    }

    /// Rejects videos with missing or null required fields.
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

    /// Preserves each documented playback format without restricting API metadata.
    @Test(arguments: ["hls", "webm", "mp4", "mp3"])
    func documentedSourceFormatsArePreserved(format: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["url": "https://cdn.example.com/asset", "format": format])
        let source = try JSONDecoder().decode(YouVersionVideo.PlaybackSource.self, from: data)
        #expect(source.format == format)
    }

    /// Rejects playback sources missing their required URL or format.
    @Test(arguments: ["url", "format"])
    func playbackSourcesRequireURLAndFormat(field: String) throws {
        var object = ["url": "https://cdn.example.com/asset", "format": "hls"]
        object.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionVideo.PlaybackSource.self, from: data) }
    }

    /// Rejects a fractional runtime rather than silently rounding it.
    @Test func runtimeIsAnIntegerNumberOfSeconds() throws {
        let json = videoJSON.replacingOccurrences(of: "\"runtime\":315", with: "\"runtime\":315.5")
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionVideo.self, from: Data(json.utf8)) }
    }

    /// Resolves production thumbnail templates while preserving aspect ratio for each requested size.
    @MainActor
    @Test(arguments: [nil, "thumb", "card", "full"] as [String?])
    func productionThumbnailTemplatesResolveSize(size: String?) async throws {
        let originalAppKey = YouVersionPlatformConfiguration.appKey
        YouVersionPlatformConfiguration.configure(appKey: "thumbnail-tests")
        defer { YouVersionPlatformConfiguration.configure(appKey: originalAppKey) }
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = videoJSON.replacingOccurrences(
            of: "https://cdn.example.com/video-images/image.jpg",
            with: "https://images.example.com/{width}x{height}/https://assets.example.com/videos/image.jpg"
        )
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.url?.path.hasPrefix("/v1/videos/") == true)
            return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let video = try await YouVersionAPI.Videos.video(id: "opaque.video-id", size: size, session: session)
        let thumbnailURL = try #require(video.thumbnail?.url)
        let expectedWidth = size == "thumb" ? 320 : size == "card" ? 1200 : 0
        #expect(thumbnailURL.host == "images.example.com")
        #expect(thumbnailURL.path == "/\(expectedWidth)x0/https://assets.example.com/videos/image.jpg")
        #expect(thumbnailURL.query == nil)
        #expect(!thumbnailURL.absoluteString.contains("%7B"))
    }

    /// Accepts the returned video ID unchanged in a subsequent request.
    @MainActor
    @Test func subsequentRequestsUseTheLatestResponseIdentifier() async throws {
        let originalAppKey = YouVersionPlatformConfiguration.appKey
        YouVersionPlatformConfiguration.configure(appKey: "thumbnail-tests")
        defer { YouVersionPlatformConfiguration.configure(appKey: originalAppKey) }
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

    /// Maps HTTP 204 to an empty playlist page without a continuation token.
    @Test(arguments: ["", "unexpected response body"])
    func noContentReturnsEmptyPlaylistPage(responseBody: String) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data(responseBody.utf8), HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil,
                                                    headerFields: ["X-Request-ID": "playlist-204-test"])!)
        }
        let page = try await YouVersionAPI.Videos.playlists(organizationID: "org", pageSize: "99", pageToken: "diagnostics", session: session)
        #expect(page.playlists.isEmpty)
        #expect(page.nextPageToken == nil)
    }

    /// Uses the shared HTTP error mapping for all video API accessors.
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

    /// Rejects empty resource IDs before sending a request.
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

    /// Rejects page sizes outside the documented range before networking.
    @Test(arguments: [0, -1, 100, Int.max])
    func invalidPageSizesFailBeforeNetworking(pageSize: Int) async {
        await #expect {
            try await YouVersionAPI.Videos.playlists(organizationID: "org", pageSize: String(pageSize))
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
    }

    /// Preserves video language preferences while retaining the temporary playlist English override.
    @MainActor
    @Test func onlyPlaylistsOverrideSessionLanguagePreferences() async throws {
        let originalAppKey = YouVersionPlatformConfiguration.appKey
        YouVersionPlatformConfiguration.configure(appKey: "thumbnail-tests")
        defer { YouVersionPlatformConfiguration.configure(appKey: originalAppKey) }
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
            let isVideo = request.url!.path.hasPrefix("/v1/videos/")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == (isVideo ? "en-US,en;q=0.9" : "en"))
            let data = isVideo ? videoData : Data("{\"data\":[]}".utf8)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        _ = try await YouVersionAPI.Videos.playlists(organizationID: "org", session: session)
        _ = try await YouVersionAPI.Videos.video(id: "video", session: session)
    }

    /// Refreshes expired default credentials while preserving explicit token overrides in every accessor.
    @Test(arguments: ["playlists", "playlist", "video", "imageSearch", "videoSearch", "images", "image"], [false, true])
    func tokenResolutionRefreshesOnlyDefaultCredentials(endpoint: String, usesExplicitToken: Bool) async throws {
        let originalAppKey = YouVersionPlatformConfiguration.appKey
        await YouVersionPlatformConfiguration.configure(appKey: "video-refresh-tests")
        await YouVersionPlatformConfiguration.saveAuthData(
            accessToken: "expired-video-token", refreshToken: "video-refresh-token", idToken: nil,
            expiryDate: Date(timeIntervalSinceNow: -60)
        )
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let resourceData: Data
        switch endpoint {
        case "video": resourceData = Data(videoJSON.utf8)
        case "image": resourceData = Data("""
            {"id":"art","image_url":"https://cdn.example.com/art.jpg","passage_id":"JHN.3.16",
            "attribution":"Example","language_tag":"en","width":100,"height":100,"aspect_ratio":1}
            """.utf8)
        case "imageSearch": resourceData = Data("{\"images\":[]}".utf8)
        case "videoSearch": resourceData = Data("{\"videos\":[],\"did_you_mean\":[]}".utf8)
        case "playlist": resourceData = Data("{\"id\":3669,\"title\":\"Test\",\"type\":\"VIDEOS\",\"total\":0,\"videos\":[]}".utf8)
        default: resourceData = Data("{\"data\":[]}".utf8)
        }
        let expectedToken = usesExplicitToken ? "explicit-video-token" : "refreshed-video-token"
        HTTPMocking.setHandler(token: token) { request in
            let data: Data
            if request.url?.path == "/auth/token" {
                #expect(!usesExplicitToken)
                #expect(request.httpMethod == "POST")
                data = Data("""
                {"access_token":"refreshed-video-token","refresh_token":"new-video-refresh","expires_in":"7200","scope":""}
                """.utf8)
            } else {
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(expectedToken)")
                data = resourceData
            }
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        do {
            let accessToken = usesExplicitToken ? expectedToken : nil
            switch endpoint {
            case "playlists": _ = try await YouVersionAPI.Videos.playlists(organizationID: "org", accessToken: accessToken, session: session)
            case "images":
                _ = try await YouVersionAPI.Images.images(accessToken: accessToken, session: session)
            case "image":
                _ = try await YouVersionAPI.Images.image(id: "art", accessToken: accessToken, session: session)
            case "imageSearch":
                _ = try await YouVersionAPI.Search.images(query: "love", bibleID: 3034, accessToken: accessToken, session: session)
            case "videoSearch":
                _ = try await YouVersionAPI.Search.videos(query: "love", accessToken: accessToken, session: session)
            case "playlist": _ = try await YouVersionAPI.Videos.playlist(organizationID: "org", id: 3669, accessToken: accessToken, session: session)
            default: _ = try await YouVersionAPI.Videos.video(id: "video", accessToken: accessToken, session: session)
            }
            #expect(YouVersionPlatformConfiguration.accessToken == (usesExplicitToken ? "expired-video-token" : expectedToken))
        } catch {
            await YouVersionPlatformConfiguration.clearAuthTokens()
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            throw error
        }
        await YouVersionPlatformConfiguration.clearAuthTokens()
        await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
    }

    /// Propagates decoding failures instead of reporting an empty collection.
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
