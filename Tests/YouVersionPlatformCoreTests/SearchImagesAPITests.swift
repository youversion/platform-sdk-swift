import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import YouVersionPlatformCore

struct SearchImagesAPITests {
    @Test
    func populatedPagePreservesHitsAndSendsContinuationParameters() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let pageToken = "a+b/c==&?% fragment"
        let json = Data("""
        {"images":[{"id":"opaque.first+id/=","passage_id":"1CO.13.4-8"},{"id":"opaque.second","passage_id":"EPH.3.17-19"}],
        "next_page_token":"next+opaque/="}
        """.utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer images-tests")
            #expect(components.path == "/v1/search-images")
            #expect(components.queryItems?.contains(URLQueryItem(name: "query", value: "love")) == true)
            #expect(components.queryItems?.contains(URLQueryItem(name: "bible_id", value: "3034")) == true)
            #expect(components.queryItems?.contains(URLQueryItem(name: "page_size", value: "25")) == true)
            #expect(components.queryItems?.contains(URLQueryItem(name: "page_token", value: pageToken)) == true)
            #expect(components.percentEncodedQuery?.contains("a%2Bb") == true)
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let results = try await YouVersionAPI.Search.images(
            query: "love", bibleID: 3034, pageSize: 25, pageToken: pageToken,
            accessToken: "images-tests", session: session
        )

        #expect(results.images.map(\.id) == ["opaque.first+id/=", "opaque.second"])
        #expect(results.images.map(\.passageID) == ["1CO.13.4-8", "EPH.3.17-19"])
        #expect(results.nextPageToken == "next+opaque/=")
    }

    @Test(arguments: ["{\"images\":[]}", "{\"images\":[],\"next_page_token\":null}"])
    func emptySearchReturnsEmptyPageAndOmitsOptionalParameters(json: String) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.queryItems?.map(\.name).sorted() == ["bible_id", "query"])
            return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let results = try await YouVersionAPI.Search.images(
            query: "nothing matches", bibleID: 3034, accessToken: "images-tests", session: session
        )

        #expect(results.images.isEmpty)
        #expect(results.nextPageToken == nil)
    }

    @Test
    func finalPageHasHitsAndNoContinuationToken() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = Data("{\"images\":[{\"id\":\"opaque\",\"passage_id\":\"JHN.3.16\"}],\"next_page_token\":null}".utf8)
        HTTPMocking.setHandler(token: token) { request in
            (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let results = try await YouVersionAPI.Search.images(
            query: "love", bibleID: 3034, accessToken: "images-tests", session: session
        )

        #expect(results.images.map(\.id) == ["opaque"])
        #expect(results.nextPageToken == nil)
    }

    @Test
    func returnedTokenLoadsNextPageAndHitResolvesThroughImageDetail() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let hitID = "opaque.hit+id/="
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let body: String
            if components.path == "/v1/search-images" {
                #expect(components.queryItems?.contains(URLQueryItem(name: "query", value: "love")) == true)
                #expect(components.queryItems?.contains(URLQueryItem(name: "bible_id", value: "3034")) == true)
                #expect(components.queryItems?.contains(URLQueryItem(name: "page_size", value: "25")) == true)
                let sentToken = components.queryItems?.first { $0.name == "page_token" }?.value
                body = sentToken == "next+opaque/="
                    ? "{\"images\":[{\"id\":\"\(hitID)\",\"passage_id\":\"JHN.3.16\"}],\"next_page_token\":null}"
                    : "{\"images\":[],\"next_page_token\":\"next+opaque/=\"}"
            } else {
                #expect(components.percentEncodedPath.removingPercentEncoding == "/v1/images/\(hitID)")
                body = """
                {"id":"reissued","image_url":"https://cdn.youversion.com/art.jpg","passage_id":"JHN.3.16",
                "attribution":"© YouVersion","language_tag":"en","width":1080,"height":1920,"aspect_ratio":0.562}
                """
            }
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let first = try await YouVersionAPI.Search.images(
            query: "love", bibleID: 3034, pageSize: 25, accessToken: "images-tests", session: session
        )
        let second = try await YouVersionAPI.Search.images(
            query: "love", bibleID: 3034, pageSize: 25, pageToken: first.nextPageToken,
            accessToken: "images-tests", session: session
        )
        let hit = try #require(second.images.first)
        let image = try await YouVersionAPI.Images.image(id: hit.id, accessToken: "images-tests", session: session)

        #expect(image.attribution == "© YouVersion")
    }

    @Test(arguments: [
        (query: "", bibleID: 3034, pageSize: Int?.none),
        (query: String(repeating: "a", count: 101), bibleID: 3034, pageSize: Int?.none),
        (query: "love", bibleID: 0, pageSize: Int?.none),
        (query: "love", bibleID: -1, pageSize: Int?.none),
        (query: "love", bibleID: Int(Int32.max) + 1, pageSize: Int?.none),
        (query: "love", bibleID: 3034, pageSize: Int?.some(0)),
        (query: "love", bibleID: 3034, pageSize: Int?.some(100))
    ])
    func invalidParametersFailBeforeNetworking(query: String, bibleID: Int, pageSize: Int?) async {
        await #expect {
            try await YouVersionAPI.Search.images(query: query, bibleID: bibleID, pageSize: pageSize)
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
    }

    @Test(arguments: [
        (status: 401, expected: YouVersionAPIError.notPermitted),
        (status: 403, expected: YouVersionAPIError.notPermitted),
        (status: 400, expected: YouVersionAPIError.cannotDownload),
        (status: 404, expected: YouVersionAPIError.cannotDownload),
        (status: 429, expected: YouVersionAPIError.cannotDownload),
        (status: 500, expected: YouVersionAPIError.cannotDownload),
        (status: 204, expected: YouVersionAPIError.cannotDownload)
    ])
    func httpFailuresUseSharedErrorMappingAndNoContentIsNotAnEmptyPage(status: Int, expected: YouVersionAPIError) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }

        await #expect(throws: expected) {
            try await YouVersionAPI.Search.images(
                query: "love", bibleID: 3034, accessToken: "images-tests", session: session
            )
        }
    }

    @Test
    func malformedResponsePropagatesDecodingError() async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        await #expect(throws: DecodingError.self) {
            try await YouVersionAPI.Search.images(
                query: "love", bibleID: 3034, accessToken: "images-tests", session: session
            )
        }
    }
}
