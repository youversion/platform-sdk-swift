import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct BibleVersionAPITests {

    @MainActor
    @Test func basicVersionDecodes() async throws {
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

        let version = try await YouVersionAPI.Bible.basicVersion(versionId: 1, accessToken: "swift-test-suite", session: session)
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

        let v = try await YouVersionAPI.Bible.version(versionId: 1, accessToken: "swift-test-suite", session: session)
        #expect(v.id == 1)
        #expect(v.textDirection == "ltr")
        let gen = v.books?.first
        #expect(gen?.chapters?.count == 2)
    }

    @MainActor
    @Test func chapterSuccessParsesContent() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"content":"<div>ok</div>"}
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, resp)
        }

        let ref = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
        let html = try await YouVersionAPI.Bible.chapter(reference: ref, accessToken: "swift-test-suite", session: session)
        #expect(html == "<div>ok</div>")
    }

    @MainActor
    @Test func chapter403ThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (Data(), resp)
        }

        let ref = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
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

        let ref = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
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

        let ref = BibleReference(versionId: 1, bookUSFM: "GEN", chapter: 1)
        await #expect(throws: YouVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.Bible.chapter(reference: ref, accessToken: "swift-test-suite", session: session)
        }
    }
}
