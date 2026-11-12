import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import YouVersionPlatformCore

extension ConfigurationStateTests {
    @Suite(.serialized)
    struct SearchVideosAPITests {
        private let emptyPage = """
        {"videos":[],"user_intent":null,"did_you_mean":[],"search_instead_for":null}
        """

        /// Resolves full video resources while preserving filters, language, thumbnails and query metadata.
        @MainActor
        @Test func fullResourcesResolveThumbnailsAndPreserveQueryMetadata() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            YouVersionPlatformConfiguration.configure(appKey: "search+key&=/")
            defer { YouVersionPlatformConfiguration.configure(appKey: originalAppKey) }
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            let organizationIDs = ["09d8dc67-6b79-4db8-95fb-b9055258b85b", "550E8400-E29B-41D4-A716-446655440000"]
            let pageToken = "a+b/c==&?% fragment"
            let json = """
            {"videos":[{"id":"new+opaque/id=","title":"Love","passage_id":"JHN.3.16+JHN.3.18","language_tag":"en",
            "thumbnail":{"url":"https://cdn.example.com/video-images/art.jpg?signature=a%2Bb%2F%3D&app_key=old&size=thumb"},
            "playback_sources":[{"url":"https://media.example.com/clip.m3u8","format":"hls"}],"playback_preview_sources":[]}],
            "user_intent":"text","did_you_mean":["love"],"search_instead_for":"love","next_page_token":"next+opaque/="}
            """
            HTTPMocking.setHandler(token: token) { @Sendable request in
                let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
                #expect(request.httpMethod == "GET")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer search-tests")
                #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en-US,en;q=0.9")
                #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
                #expect(components.path == "/v1-beta/search-videos")
                #expect(components.queryItems?.filter { $0.name == "organization_ids[]" }.compactMap(\.value) == organizationIDs)
                #expect(components.queryItems?.contains(URLQueryItem(name: "page_token", value: pageToken)) == true)
                #expect(components.queryItems?.contains(URLQueryItem(name: "query", value: "love + peace")) == true)
                #expect(components.queryItems?.contains(URLQueryItem(name: "page_size", value: "99")) == true)
                #expect(components.percentEncodedQuery?.contains("a%2Bb") == true)
                return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            let page = try await YouVersionAPI.Search.videos(
                query: "love + peace", organizationIDs: organizationIDs, acceptLanguage: "en-US,en;q=0.9",
                pageSize: 99, pageToken: pageToken, accessToken: "search-tests", session: session
            )
            let video = try #require(page.videos.first)
            #expect(video.id == "new+opaque/id=")
            #expect(video.passageID == "JHN.3.16+JHN.3.18")
            #expect(video.references == nil)
            #expect(video.playbackSources.first?.format == "hls")
            let thumbnailURL = try #require(video.thumbnail?.url)
            let thumbnail = try #require(URLComponents(url: thumbnailURL, resolvingAgainstBaseURL: false))
            #expect(thumbnail.queryItems?.filter { $0.name == "app_key" }.map(\.value) == ["search+key&=/"])
            #expect(thumbnail.queryItems?.contains { $0.name == "size" } == false)
            #expect(thumbnail.percentEncodedQuery?.contains("signature=a%2Bb%2F%3D") == true)
            #expect(page.userIntent == .text)
            #expect(page.didYouMean == ["love"])
            #expect(page.searchInsteadFor == "love")
            #expect(page.nextPageToken == "next+opaque/=")
        }

        /// Preserves continuation on an empty page and allows the next page size to change.
        @Test func emptyPageCanContinueWithDifferentPageSize() async throws {
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            let emptyPage = emptyPage
            HTTPMocking.setHandler(token: token) { @Sendable request in
                let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
                #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
                let sentToken = components.queryItems?.first { $0.name == "page_token" }?.value
                let body: String
                if sentToken == "next+opaque/=" {
                    #expect(components.queryItems?.contains(URLQueryItem(name: "page_size", value: "1")) == true)
                    body = """
                    {"videos":[{"id":"last","playback_sources":[],"playback_preview_sources":[]}],
                    "user_intent":null,"did_you_mean":[],"search_instead_for":null}
                    """
                } else {
                    #expect(components.queryItems?.map(\.name) == ["query"])
                    body = String(emptyPage.dropLast()) + ",\"next_page_token\":\"next+opaque/=\"}"
                }
                return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            let first = try await YouVersionAPI.Search.videos(query: "love", accessToken: "search-tests", session: session)
            #expect(first.videos.isEmpty)
            #expect(first.nextPageToken == "next+opaque/=")
            let second = try await YouVersionAPI.Search.videos(
                query: "love", pageSize: 1, pageToken: first.nextPageToken, accessToken: "search-tests", session: session
            )
            #expect(second.videos.map(\.id) == ["last"])
            #expect(second.nextPageToken == nil)
        }

        /// Rejects invalid query, publisher and page-size parameters before networking.
        @Test(arguments: [
            (query: "", organizationIDs: [String](), pageSize: Int?.none),
            (query: String(repeating: "a", count: 101), organizationIDs: [], pageSize: nil),
            (query: "love", organizationIDs: ["not-a-uuid"], pageSize: nil),
            (query: "love", organizationIDs: [], pageSize: 0),
            (query: "love", organizationIDs: [], pageSize: 100)
        ])
        func invalidParametersFailBeforeNetworking(query: String, organizationIDs: [String], pageSize: Int?) async {
            await #expect {
                try await YouVersionAPI.Search.videos(query: query, organizationIDs: organizationIDs, pageSize: pageSize)
            } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
        }

        /// Maps video-search HTTP failures through the shared API error handling.
        @Test(arguments: [
            (status: 401, expected: YouVersionAPIError.notPermitted),
            (status: 403, expected: YouVersionAPIError.notPermitted),
            (status: 400, expected: YouVersionAPIError.cannotDownload),
            (status: 424, expected: YouVersionAPIError.cannotDownload),
            (status: 502, expected: YouVersionAPIError.cannotDownload)
        ])
        func httpFailuresUseSharedErrorMapping(status: Int, expected: YouVersionAPIError) async {
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            HTTPMocking.setHandler(token: token) { @Sendable request in
                (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
            }
            await #expect(throws: expected) {
                try await YouVersionAPI.Search.videos(query: "love", accessToken: "search-tests", session: session)
            }
        }

        /// Propagates malformed video-search responses instead of returning an empty page.
        @Test func malformedResponseIsNotSilentlyAnEmptyPage() async {
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            HTTPMocking.setHandler(token: token) { @Sendable request in
                (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            await #expect(throws: DecodingError.self) {
                try await YouVersionAPI.Search.videos(query: "love", accessToken: "search-tests", session: session)
            }
        }
    }
}
