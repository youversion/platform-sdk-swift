import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import YouVersionPlatformCore

struct ImagesAPITests {
    private let imageJSON = """
    {"id":"opaque.image-id","image_url":"https://cdn.youversion.com/art.jpg?app_key=example&other=1",
    "passage_id":"1CO.13.4-7","attribution":"© YouVersion","language_tag":"en-US",
    "width":1080,"height":1920,"aspect_ratio":0.562}
    """

    @Test
    func collectionPreservesFiltersAndPagination() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let pageToken = "a+b/c==&?% fragment"
        let json = Data("{\"data\":[\(imageJSON)],\"total_size\":41,\"next_page_token\":\"next+opaque/=\"}".utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer images-tests")
            #expect(components.path == "/v1/images")
            #expect(components.queryItems?.filter { $0.name == "language_ranges[]" }.compactMap(\.value) == ["en_US", "es", "*"])
            #expect(components.queryItems?.contains(URLQueryItem(name: "passage_id", value: "1CO.13.4-7")) == true)
            #expect(components.queryItems?.contains(URLQueryItem(name: "page_size", value: "99")) == true)
            #expect(components.queryItems?.contains(URLQueryItem(name: "page_token", value: pageToken)) == true)
            #expect(components.percentEncodedQuery?.contains("a%2Bb") == true)
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let result = try await YouVersionAPI.Images.images(
            passageID: "1CO.13.4-7", languageRanges: ["en_US", "es", "*"], pageSize: 99,
            pageToken: pageToken, accessToken: "images-tests", session: session
        )
        #expect(result.totalSize == 41)
        #expect(result.nextPageToken == "next+opaque/=")
        let image = try #require(result.images.first)
        #expect(image.id == "opaque.image-id")
        #expect(image.url.absoluteString == "https://cdn.youversion.com/art.jpg?app_key=example&other=1")
        #expect(image.passageID == "1CO.13.4-7")
        #expect(image.attribution == "© YouVersion")
        #expect(image.languageTag == "en-US")
        #expect(image.width == 1080)
        #expect(image.height == 1920)
        #expect(image.aspectRatio == 0.562)
    }

    @Test(arguments: ["{\"data\":[]}", "{\"data\":[],\"total_size\":null,\"next_page_token\":null}"])
    func unfilteredCollectionOmitsDefaultsAndAcceptsUnknownTotals(json: String) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.url?.query == nil)
            return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let result = try await YouVersionAPI.Images.images(accessToken: "images-tests", session: session)
        #expect(result.images.isEmpty)
        #expect(result.totalSize == nil)
        #expect(result.nextPageToken == nil)
    }

    @Test(arguments: ["id/with?query#fragment%2F +é", ".", ".."])
    func detailTreatsOpaqueIdentifierAsSingleSegment(id: String) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = Data(imageJSON.utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let prefix = "/v1/images/"
            #expect(components.percentEncodedPath.hasPrefix(prefix))
            let segment = String(components.percentEncodedPath.dropFirst(prefix.count))
            #expect(!segment.contains("/"))
            #expect(segment.removingPercentEncoding == id)
            #expect(components.query == nil)
            #expect(components.fragment == nil)
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let image = try await YouVersionAPI.Images.image(
            id: id, accessToken: "images-tests", session: session
        )
        #expect(image.id == "opaque.image-id")
    }

    @Test(arguments: [0, -1, 100, Int.max])
    func invalidPageSizesFailBeforeNetworking(pageSize: Int) async {
        await #expect {
            try await YouVersionAPI.Images.images(pageSize: pageSize)
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
    }

    @Test(arguments: ["", "en--US", "en*", "en\n", "abcdefghi", "en/US"])
    func languageRangesAreForwardedAndServerRejectionsPropagate(languageRange: String) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.queryItems?.filter { $0.name == "language_ranges[]" }.compactMap(\.value) == [languageRange])
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        }
        await #expect {
            try await YouVersionAPI.Images.images(
                languageRanges: [languageRange], accessToken: "images-tests", session: session
            )
        } throws: { ($0 as? YouVersionAPIError) == .cannotDownload }
    }

    @Test
    func emptyIdentifierFailsBeforeNetworking() async {
        await #expect {
            try await YouVersionAPI.Images.image(id: "")
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
    }

    @Test(arguments: [false, true])
    func networkFailuresPropagate(isDetail: Bool) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { _ in throw URLError(.timedOut) }
        await #expect {
            if isDetail {
                _ = try await YouVersionAPI.Images.image(id: "opaque", accessToken: "images-tests", session: session)
            } else {
                _ = try await YouVersionAPI.Images.images(accessToken: "images-tests", session: session)
            }
        } throws: { ($0 as? URLError)?.code == .timedOut }
    }

    @Test
    func minimumPageSizeAndSpecLanguageRangesAreAccepted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.queryItems?.contains(URLQueryItem(name: "page_size", value: "1")) == true)
            return (Data("{\"data\":[]}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        _ = try await YouVersionAPI.Images.images(
            languageRanges: ["123", "en-US", "en_US", "*"], pageSize: 1,
            accessToken: "images-tests", session: session
        )
    }

    @Test(arguments: [401, 403, 400, 404, 429, 500, 204], [false, true])
    func httpFailuresUseSharedErrorMapping(status: Int, isDetail: Bool) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        await #expect {
            if isDetail {
                _ = try await YouVersionAPI.Images.image(id: "opaque", accessToken: "images-tests", session: session)
            } else {
                _ = try await YouVersionAPI.Images.images(accessToken: "images-tests", session: session)
            }
        } throws: { error in
            if case YouVersionAPIError.notPermitted = error { return status == 401 || status == 403 }
            if case YouVersionAPIError.cannotDownload = error { return status != 401 && status != 403 }
            return false
        }
    }

    @Test(arguments: ["id", "image_url", "passage_id", "attribution", "language_tag", "width", "height", "aspect_ratio"])
    func everyImageFieldIsRequired(field: String) throws {
        var object = try #require(JSONSerialization.jsonObject(with: Data(imageJSON.utf8)) as? [String: Any])
        object.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionImage.self, from: data) }
        object[field] = NSNull()
        let nullData = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(YouVersionImage.self, from: nullData) }
    }

    @Test(arguments: [false, true])
    func malformedResponsesPropagateDecodingErrors(isDetail: Bool) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await #expect(throws: DecodingError.self) {
            if isDetail {
                _ = try await YouVersionAPI.Images.image(id: "opaque", accessToken: "images-tests", session: session)
            } else {
                _ = try await YouVersionAPI.Images.images(accessToken: "images-tests", session: session)
            }
        }
    }
}
