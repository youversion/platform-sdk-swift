import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

extension URLRequest {
    func bodyStreamAsJSON() -> Any? {
        if let bodyData = self.httpBody {
            return try? JSONSerialization.jsonObject(with: bodyData, options: .allowFragments)
        }
        guard let bodyStream = self.httpBodyStream else { return nil }

        bodyStream.open()

        // Will read 16 chars per iteration. Can use bigger buffer if needed
        let bufferSize: Int = 16

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        var dat = Data()

        while bodyStream.hasBytesAvailable {
            let readDat = bodyStream.read(buffer, maxLength: bufferSize)
            dat.append(buffer, count: readDat)
        }

        buffer.deallocate()

        bodyStream.close()

        do {
            return try JSONSerialization.jsonObject(with: dat, options: JSONSerialization.ReadingOptions.allowFragments)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}

@Suite(.serialized) struct HighlightsAPITests {

    @MainActor
    @Test func testCreateHighlightSuccess() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app", accessToken: "token")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        struct Body: Decodable { let bible_id: Int; let passage_id: String; let color: String }
        var captured: URLRequest?
        var capturedJSONBody: Any?

        HTTPMocking.setHandler(token: token) { request in
            captured = request
            capturedJSONBody = request.bodyStreamAsJSON()
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let result = try await YouVersionAPI.Highlights.createHighlight(
            bibleId: 1,
            passageId: "GEN.1.1",
            color: "FF00FF",
            session: session
        )

        let request = try #require(captured)
        #expect(request.httpMethod == "POST")
        
        // Validate the actual JSON body from the request
        let jsonBody = try #require(capturedJSONBody)
        let jsonData = try JSONSerialization.data(withJSONObject: jsonBody)
        let decoded = try JSONDecoder().decode(Body.self, from: jsonData)
        #expect(decoded.bible_id == 1)
        #expect(decoded.passage_id == "GEN.1.1")
        #expect(decoded.color == "ff00ff")
        #expect(result)
    }

    @MainActor
    @Test func testGetHighlightsParsesResponse() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app", accessToken: "token")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"data": [{"id": "1","bible_id": 1,"passage_id": "GEN.9.1","color": "ff00ff"}],"next_page_token": null}
        """.data(using: .utf8)!
        var captured: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let highlights = try await YouVersionAPI.Highlights.getHighlights(
            bibleId: 1,
            passageId: "GEN.9",
            session: session
        )

        let request = try #require(captured)
        #expect(request.httpMethod == "GET")
        let components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        let items = components.queryItems ?? []
        #expect(items.first { $0.name == "bible_id" }?.value == "1")
        #expect(items.first { $0.name == "passage_id" }?.value == "GEN.9")
        #expect(highlights.count == 1)
        #expect(highlights.first?.passageId == "GEN.9.1")
    }

    @MainActor
    @Test func testGetHighlightsUnauthorizedReturnsEmpty() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app", accessToken: "token")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let highlights = try await YouVersionAPI.Highlights.getHighlights(
            bibleId: 1,
            passageId: "GEN.1",
            session: session
        )
        #expect(highlights.isEmpty)
    }

    @MainActor
    @Test func testDeleteHighlightSuccess() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app", accessToken: "token")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        var captured: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let success = try await YouVersionAPI.Highlights.deleteHighlight(
            bibleId: 1,
            passageId: "GEN.5.7",
            session: session
        )

        let request = try #require(captured)
        #expect(request.httpMethod == "DELETE")

        // Validate the URL query parameters (DELETE requests use query params, not body)
        let components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        let items = components.queryItems ?? []
        #expect(items.first { $0.name == "bible_id" }?.value == "1")
        #expect(components.path.contains("GEN.5.7"))
        #expect(success)
    }

    @MainActor
    @Test func testUpdateHighlightSuccess() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app", accessToken: "token")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        var captured: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let success = try await YouVersionAPI.Highlights.updateHighlight(
            bibleId: 1,
            passageId: "GEN.1.1",
            color: "ABCDEF",
            session: session
        )

        let request = try #require(captured)
        #expect(request.httpMethod == "PUT")
        #expect(success)
    }

    @MainActor
    @Test func testGetHighlights204ReturnsEmpty() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app", accessToken: "token")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let highlights = try await YouVersionAPI.Highlights.getHighlights(
            bibleId: 1,
            passageId: "GEN.1",
            session: session
        )
        #expect(highlights.isEmpty)
    }

    @MainActor
    @Test func testGetHighlightsUnexpectedStatusReturnsEmpty() async throws {
        YouVersionPlatformConfiguration.configure(appKey: "app", accessToken: "token")
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let highlights = try await YouVersionAPI.Highlights.getHighlights(
            bibleId: 1,
            passageId: "GEN.1",
            session: session
        )
        #expect(highlights.isEmpty)
    }
}

