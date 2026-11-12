import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

extension ConfigurationStateTests {
    @Suite(.serialized)
    struct VideoSearchAndPlaylistSelectionTests {
        /// Preserves opaque unified video IDs and the requested result fields.
        @Test(arguments: [["videos"], ["videos", "verses"]])
        func unifiedPreservesVideoIDsAndRequestsVideoFields(fields: [String]) async throws {
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            HTTPMocking.setHandler(token: token) { request in
                let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
                #expect(components.path == "/v1-beta/search-unified")
                #expect(components.queryItems?.filter { $0.name == "fields[]" }.compactMap(\.value) == fields)
                let json = #"{"videos":[{"id":"opaque.+/=?&"},{"id":"second"}]}"#
                return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            let result = try await YouVersionAPI.Search.unified(
                matching: "love", bibleID: 111, languageRanges: ["en"], fields: fields, session: session
            )
            #expect(result.videos.map(\.id) == ["opaque.+/=?&", "second"])
            #expect(result.references.isEmpty)
            #expect(result.images.isEmpty)
            #expect(result.topics.isEmpty)
        }

        /// Treats omitted, null and empty video results as an empty collection.
        @Test(arguments: [#"{}"#, #"{"videos":[]}"#, #"{"videos":null}"#])
        func absentVideoResultsAreEmpty(json: String) async throws {
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            HTTPMocking.setHandler(token: token) { request in
                (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            let result = try await YouVersionAPI.Search.unified(matching: "love", bibleID: 111, languageRanges: ["en"], session: session)
            #expect(result.videos.isEmpty)
        }

        /// Rejects video hits without a valid string identifier.
        @Test(arguments: [#"{"videos":[{}]}"#, #"{"videos":[{"id":null}]}"#, #"{"videos":[{"id":42}]}"#])
        func malformedVideoHitsFailDecoding(json: String) async throws {
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            HTTPMocking.setHandler(token: token) { request in
                (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            await #expect(throws: DecodingError.self) {
                try await YouVersionAPI.Search.unified(matching: "love", bibleID: 111, languageRanges: ["en"], session: session)
            }
        }

        /// Preserves selected playlist fields, page sizes and opaque continuation tokens.
        @Test(arguments: [nil, "1", "99", "*"])
        func selectedPlaylistsPreserveFieldsAndCursor(pageSize: String?) async throws {
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            let cursor = "a+b/c==&?%"
            HTTPMocking.setHandler(token: token) { request in
                let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
                #expect(components.queryItems?.filter { $0.name == "fields[]" }.compactMap(\.value) == ["id", "title"])
                #expect(components.queryItems?.first { $0.name == "page_size" }?.value == pageSize)
                #expect(components.queryItems?.first { $0.name == "page_token" }?.value == cursor)
                #expect(components.path == "/v1-beta/organizations/org/id/playlists")
                #expect(request.cachePolicy == .useProtocolCachePolicy)
                #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
                #expect(components.percentEncodedPath.contains("org%2Fid"))
                #expect(components.percentEncodedQuery?.contains("a%2Bb") == true)
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer selection-tests")
                let json = #"{"data":[{"id":12,"title":"Creation"}],"next_page_token":"next+token"}"#
                return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            let page = try await YouVersionAPI.Videos.playlists(
                organizationID: "org/id", fields: ["id", "title"], pageSize: pageSize,
                pageToken: cursor, accessToken: "selection-tests", session: session
            )
            let playlist = try #require(page.playlists.first)
            #expect(playlist.id == 12)
            #expect(playlist.title == "Creation")
            #expect(playlist.videoIDs == nil)
            #expect(playlist.total == nil)
            #expect(playlist.type == nil)
            #expect(playlist.description == nil)
            #expect(page.nextPageToken == "next+token")
        }

        /// Decodes every supported playlist selection field.
        @Test
        func selectedPlaylistDecodesAllSupportedFields() throws {
            let json = #"{"data":[{"id":12,"title":"Creation","description":"Description","type":"VIDEOS","total":0,"videos":[]}]}"#
            let page = try JSONDecoder().decode(YouVersionVideoPlaylistCollection.self, from: Data(json.utf8))
            let playlist = try #require(page.playlists.first)
            #expect(playlist.description == "Description")
            #expect(playlist.type == "VIDEOS")
            #expect(playlist.total == 0)
            #expect(playlist.videoIDs == [])
            #expect(page.nextPageToken == nil)
            #expect(try JSONDecoder().decode(YouVersionVideoPlaylistCollection.self, from: JSONEncoder().encode(page)) == page)
        }

        /// Leaves unselected playlist fields absent for an identifier-only response.
        @Test
        func identifierOnlySelectionLeavesOtherFieldsAbsent() throws {
            let json = #"{"data":[{"id":12}]}"#
            let page = try JSONDecoder().decode(YouVersionVideoPlaylistCollection.self, from: Data(json.utf8))
            let playlist = try #require(page.playlists.first)
            #expect(playlist.id == 12)
            #expect(playlist.title == nil)
            #expect(playlist.videoIDs == nil)
            #expect(playlist.total == nil)
        }

        /// Maps a no-content selection response to an empty playlist page.
        @Test
        func selectedPlaylistNoContentReturnsEmptyPage() async throws {
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            HTTPMocking.setHandler(token: token) { request in
                (Data(), HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!)
            }
            let page = try await YouVersionAPI.Videos.playlists(organizationID: "org", fields: ["id"], pageSize: "*", session: session)
            #expect(page.playlists.isEmpty)
            #expect(page.nextPageToken == nil)
            let search = try await YouVersionAPI.Search.unified(matching: "love", bibleID: 111, languageRanges: ["en"], session: session)
            #expect(search.videos.isEmpty)
        }

        /// Rejects invalid numeric playlist page sizes before networking.
        @Test(arguments: ["0", "100", "-1", "", "invalid", "01", "1.5"])
        func invalidSelectionPageSizeIsRejected(pageSize: String) async {
            await #expect(throws: YouVersionAPIRequestError.self) {
                try await YouVersionAPI.Videos.playlists(organizationID: "org", fields: ["id"], pageSize: pageSize)
            }
        }

        /// Rejects wildcard pagination without one to three supported fields.
        @Test(arguments: [nil, [], ["unknown"], ["id", "title", "type", "total"]] as [[String]?])
        func invalidWildcardSelectionIsRejected(fields: [String]?) async {
            await #expect(throws: YouVersionAPIRequestError.self) {
                try await YouVersionAPI.Videos.playlists(organizationID: "org", fields: fields, pageSize: "*")
            }
        }
    }
}
