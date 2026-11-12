import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct VOTDTests {

    @MainActor
    @Test func votdSuccessDecodes() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"day":1,"passage_id":"JHN.3.16"}
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let v = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        #expect(v.passageId == "JHN.3.16")
        #expect(v.day == 1)
    }

    @MainActor
    @Test func votdUnauthorizedThrowsMissingAuthentication() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.missingAuthentication) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func votdServerStatusThrowsServerError() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        } throws: { ($0 as? YouVersionAPIResponseError)?.code == .serverError }
    }

    @MainActor
    @Test func votdInvalidResponseThrowsInvalidResponse() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func votdMalformedJSONThrowsBadServerResponse() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let malformed = "{ bad json }".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (malformed, response)
        }

        await #expect(throws: URLError.self) {
            _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 1, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func votdRequestUsesCorrectDayInURL() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"day":99,"passage_id":"MAT.5.1"}
        """.data(using: .utf8)!
        var captured: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let _ = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: 99, accessToken: nil, session: session)
        let req = try #require(captured)
        #expect(req.url?.absoluteString.contains("/99") == true)
    }

    @Test func dayRouteSendsRepeatedLanguageRangesAndExposesImageID() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = Data("{\"day\":1,\"passage_id\":\"ISA.43.18-19\",\"image_id\":\"opaque.image+id/=\"}".utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.path == "/v1/verse-of-the-days/1")
            #expect(components.queryItems?.filter { $0.name == "language_ranges[]" }.compactMap(\.value) == ["es-MX", "es", "*"])
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let verse = try await YouVersionAPI.VOTD.verseOfTheDay(
            dayOfYear: 1, languageRanges: ["es-MX", "es", "*"], accessToken: "swift-test-suite", session: session
        )

        #expect(verse.imageID == "opaque.image+id/=")
        #expect(verse.passageId == "ISA.43.18-19")
        #expect(verse.day == 1)
    }

    @Test func dayRouteImageIDResolvesThroughImageDetailUnchanged() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let imageID = "opaque.image+id/="
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let body: String
            if components.path == "/v1/verse-of-the-days/1" {
                body = "{\"day\":1,\"passage_id\":\"JHN.3.16\",\"image_id\":\"\(imageID)\"}"
            } else {
                #expect(components.percentEncodedPath.removingPercentEncoding == "/v1/images/\(imageID)")
                body = """
                {"id":"reissued","image_url":"https://cdn.youversion.com/art.jpg","passage_id":"JHN.3.16",
                "attribution":"© YouVersion","language_tag":"en","width":1080,"height":1920,"aspect_ratio":0.562}
                """
            }
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let verse = try await YouVersionAPI.VOTD.verseOfTheDay(
            dayOfYear: 1, languageRanges: ["en"], accessToken: "swift-test-suite", session: session
        )
        let image = try await YouVersionAPI.Images.image(
            id: try #require(verse.imageID), accessToken: "swift-test-suite", session: session
        )

        #expect(image.attribution == "© YouVersion")
    }

    @Test(arguments: [
        "{\"day\":2,\"passage_id\":\"JHN.3.16\"}",
        "{\"day\":2,\"passage_id\":\"JHN.3.16\",\"image_id\":null}"
    ])
    func dayRouteOmitsLanguageRangesWhenAbsentAndToleratesNoImage(json: String) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.path == "/v1/verse-of-the-days/2")
            #expect(components.query == nil)
            return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let verse = try await YouVersionAPI.VOTD.verseOfTheDay(
            dayOfYear: 2, accessToken: "swift-test-suite", session: session
        )

        #expect(verse.imageID == nil)
        #expect(verse.passageId == "JHN.3.16")
        #expect(verse.day == 2)
    }

    @Test func yearRouteSendsRepeatedLanguageRangesAndPreservesEachDay() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = Data("""
        {"data":[{"day":1,"passage_id":"ISA.43.18-19","image_id":"opaque.image+id/="},
        {"day":2,"passage_id":"JHN.3.16","image_id":null},{"day":3,"passage_id":"PSA.23.1"}]}
        """.utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.path == "/v1/verse-of-the-days")
            #expect(components.queryItems?.filter { $0.name == "language_ranges[]" }.compactMap(\.value) == ["es-MX", "es"])
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let verses = try await YouVersionAPI.VOTD.versesOfTheDay(
            languageRanges: ["es-MX", "es"], accessToken: "swift-test-suite", session: session
        )

        #expect(verses.map(\.day) == [1, 2, 3])
        #expect(verses.map(\.passageId) == ["ISA.43.18-19", "JHN.3.16", "PSA.23.1"])
        #expect(verses.map(\.imageID) == ["opaque.image+id/=", nil, nil])
    }

    @Test func yearRouteOmitsLanguageRangesWhenAbsent() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.url?.path == "/v1/verse-of-the-days")
            #expect(request.url?.query == nil)
            return (Data("{\"data\":[]}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let verses = try await YouVersionAPI.VOTD.versesOfTheDay(accessToken: "swift-test-suite", session: session)

        #expect(verses.isEmpty)
    }

    @Test func yearRouteNoContentReturnsNoVerses() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!)
        }

        let verses = try await YouVersionAPI.VOTD.versesOfTheDay(accessToken: "swift-test-suite", session: session)

        #expect(verses.isEmpty)
    }

    @Test(arguments: [401, 403, 400, 404, 429, 500])
    func yearRouteHTTPFailuresUseSharedErrorMapping(status: Int) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }

        await #expect {
            try await YouVersionAPI.VOTD.versesOfTheDay(accessToken: "swift-test-suite", session: session)
        } throws: { error in
            HTTPStatusErrorTests.isExpectedError(error, forStatusCode: status)
        }
    }

    @Test func yearRouteMalformedJSONThrowsBadServerResponse() async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        await #expect {
            try await YouVersionAPI.VOTD.versesOfTheDay(accessToken: "swift-test-suite", session: session)
        } throws: { ($0 as? URLError)?.code == .badServerResponse }
    }
}
