import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct BibleVersionAPITests {

    @Test func cacheExpirationSubtractsResponseAge() throws {
        let currentDate = Date(timeIntervalSince1970: 10_000)
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Cache-Control": "public, max-age=86400",
                "Age": "3600"
            ]
        ))

        #expect(response.cacheExpirationDate(currentDate: currentDate) == currentDate.addingTimeInterval(82_800))
    }

    @Test func cacheExpirationUsesDefaultDurationWithoutUsableMaxAge() throws {
        let currentDate = Date(timeIntervalSince1970: 10_000)
        let url = URL(string: "https://example.com")!
        let headers = [
            [:],
            ["Cache-Control": "public"],
            ["Cache-Control": "public, max-age=invalid"]
        ]

        for headerFields in headers {
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: headerFields
            ))
            #expect(
                response.cacheExpirationDate(currentDate: currentDate)
                    == currentDate.addingTimeInterval(BibleContentCachePolicy.defaultDuration)
            )
        }
    }

    @Test func explicitNoCacheDirectivesDisableCaching() throws {
        let url = URL(string: "https://example.com")!
        let headers = [
            ["Cache-Control": "public, max-age=60, no-store"],
            ["Cache-Control": "public, max-age=60, no-cache=\"Set-Cookie\""]
        ]

        for headerFields in headers {
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: headerFields
            ))
            #expect(response.allowsCaching == false)
        }
    }

    @MainActor
    @Test func metadataForVersionDecodes() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"id": 1, "title": "Test Version", "language_tag": "en"}
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            #expect(request.url?.path.contains("/v1/bibles/1") == true)
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, resp)
        }

        let version = try await YouVersionAPI.Bible.metadataForVersion(withId: 1, accessToken: "swift-test-suite", session: session)
        #expect(version.id == 1)
        #expect(version.title == "Test Version")
        #expect(version.languageTag == "en")
    }

    @MainActor
    @Test func versionAggregatesIndexIntoBooks() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let basic = """
        {"id": 1, "title": "Test", "language_tag": "en"}
        """.data(using: .utf8)!

        let index = """
        {
          "text_direction": "ltr",
          "books": [
            {"id":"GEN","title":"Genesis","chapters":[
              {"id":"GEN.1","title":"1","verses":[{"id":"GEN.1.1","title":"1"}]},
              {"id":"GEN.2","title":"2","verses":[{"id":"GEN.2.1","title":"1"}]}
            ]}
          ]
        }
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            let path = request.url!.path
            if path.contains("/v1/bibles/1/index") {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (index, resp)
            } else if path.contains("/v1/bibles/1") {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (basic, resp)
            } else {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (Data(), resp)
            }
        }

        let v = try await YouVersionAPI.Bible.version(withId: 1, accessToken: "swift-test-suite", session: session)
        #expect(v.id == 1)
        #expect(v.textDirection == "ltr")
        let gen = v.books?.first
        #expect(gen?.chapters?.count == 2)
    }

    @MainActor
    @Test func versionResponseUsesEarliestCacheExpiration() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let basic = Data(#"{"id":1,"title":"Test","language_tag":"en"}"#.utf8)
        let index = Data(#"{"text_direction":"ltr","books":[]}"#.utf8)

        HTTPMocking.setHandler(token: token) { request in
            let isIndex = request.url?.path.contains("/index") == true
            let headers = ["Cache-Control": isIndex ? "public, max-age=60" : "public, max-age=120"]
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: headers
            )!
            return (isIndex ? index : basic, response)
        }

        let beforeRequestDate = Date()
        let response = try await YouVersionAPI.Bible.versionResponse(
            withId: 1,
            accessToken: "swift-test-suite",
            session: session
        )
        let expirationDate = try #require(response.expirationDate)

        #expect(expirationDate >= beforeRequestDate.addingTimeInterval(60))
        #expect(expirationDate <= Date().addingTimeInterval(60))
    }

    @MainActor
    @Test func versionResponseIsNotCacheableWhenEitherResponseForbidsCaching() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let basic = Data(#"{"id":1,"title":"Test","language_tag":"en"}"#.utf8)
        let index = Data(#"{"text_direction":"ltr","books":[]}"#.utf8)

        HTTPMocking.setHandler(token: token) { request in
            let isIndex = request.url?.path.contains("/index") == true
            let headers = isIndex ? ["Cache-Control": "no-store"] : ["Cache-Control": "public, max-age=120"]
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: headers
            )!
            return (isIndex ? index : basic, response)
        }

        let response = try await YouVersionAPI.Bible.versionResponse(
            withId: 1,
            accessToken: "swift-test-suite",
            session: session
        )

        #expect(response.isCacheable == false)
        #expect(response.expirationDate != nil)
    }

    @MainActor
    @Test func chapterSuccessParsesContent() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"content":"<div>ok</div>"}
        """.data(using: .utf8)!

        var capturedRequest: URLRequest?
        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, resp)
        }

        let ref = BibleReference(versionId: 1, bookId: "GEN", chapter: 1)
        let html = try await YouVersionAPI.Bible.chapter(reference: ref, accessToken: "swift-test-suite", session: session)
        #expect(html == "<div>ok</div>")

        let req = try #require(capturedRequest)
        let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        #expect(queryItems.contains(where: { $0.name == "format" && $0.value == "html" }))
        #expect(queryItems.contains(where: { $0.name == "include_notes" && $0.value == "true" }))
        #expect(queryItems.contains(where: { $0.name == "include_headings" && $0.value == "true" }))
    }

    @MainActor
    @Test func chapterResponseIncludesCacheExpiration() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = Data(#"{"content":"<div>ok</div>"}"#.utf8)

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Cache-Control": "public, max-age=86400"]
            )!
            return (json, response)
        }

        let beforeRequestDate = Date()
        let reference = BibleReference(versionId: 1, bookId: "GEN", chapter: 1)
        let response = try await YouVersionAPI.Bible.chapterResponse(
            reference: reference,
            accessToken: "swift-test-suite",
            session: session
        )
        let expirationDate = try #require(response.expirationDate)

        #expect(response.value == "<div>ok</div>")
        #expect(expirationDate >= beforeRequestDate.addingTimeInterval(86_400))
        #expect(expirationDate <= Date().addingTimeInterval(86_400))
    }

    @MainActor
    @Test func chapter403ThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (Data(), resp)
        }

        let ref = BibleReference(versionId: 1, bookId: "GEN", chapter: 1)
        await #expect(throws: YouVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.Bible.chapter(reference: ref, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func chapter500ThrowsCannotDownload() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), resp)
        }

        let ref = BibleReference(versionId: 1, bookId: "GEN", chapter: 1)
        await #expect(throws: YouVersionAPIError.cannotDownload) {
            _ = try await YouVersionAPI.Bible.chapter(reference: ref, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func chapterInvalidResponseThrows() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let resp = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), resp)
        }

        let ref = BibleReference(versionId: 1, bookId: "GEN", chapter: 1)
        await #expect(throws: YouVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.Bible.chapter(reference: ref, accessToken: "swift-test-suite", session: session)
        }
    }

    @MainActor
    @Test func chapterInvalidContentThrowsInvalidDownload() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        // 200 response with valid JSON but missing the "content" key
        let json = """
        {"other_field": "no content here"}
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, resp)
        }

        let ref = BibleReference(versionId: 1, bookId: "GEN", chapter: 1)
        await #expect(throws: YouVersionAPIError.invalidDownload) {
            _ = try await YouVersionAPI.Bible.chapter(reference: ref, accessToken: "swift-test-suite", session: session)
        }
    }
}
