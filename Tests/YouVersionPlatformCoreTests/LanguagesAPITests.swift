import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct LanguagesAPITests {

    @MainActor
    @Test func languagesSuccessReturnsData() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let expectedLanguages = [
            LanguageOverview(
                id: "en",
                language: "English",
                script: "Latn",
                scriptName: "Latin",
                aliases: ["eng"],
                displayNames: ["en": "English", "es": "Inglés"],
                scripts: ["Latn"],
                variants: ["US", "GB"],
                countries: ["US", "GB", "CA"],
                textDirection: "ltr",
                defaultBibleVersionId: 111
            ),
            LanguageOverview(
                id: "es",
                language: "Spanish",
                script: "Latn",
                scriptName: "Latin",
                aliases: ["spa"],
                displayNames: ["en": "Spanish", "es": "Español"],
                scripts: ["Latn"],
                variants: ["ES", "MX"],
                countries: ["ES", "MX", "AR"],
                textDirection: "ltr",
                defaultBibleVersionId: 128
            )
        ]

        let responseData = try JSONEncoder().encode(LanguagesResponse(data: expectedLanguages))
        var capturedRequest: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }

        let languages = try await YouVersionAPI.Languages.languages(session: session)

        #expect(languages.count == 2)
        #expect(languages[0].id == "en")
        #expect(languages[0].language == "English")
        #expect(languages[0].defaultBibleVersionId == 111)
        #expect(languages[1].id == "es")
        #expect(languages[1].language == "Spanish")
        #expect(languages[1].defaultBibleVersionId == 128)
        
        let _ = try #require(capturedRequest)
    }

    @MainActor
    @Test func languagesWithCountryParameter() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let expectedLanguages = [
            LanguageOverview(
                id: "en",
                language: "English",
                script: "Latn",
                scriptName: "Latin",
                aliases: ["eng"],
                displayNames: ["en": "English"],
                scripts: ["Latn"],
                variants: ["US"],
                countries: ["US"],
                textDirection: "ltr",
                defaultBibleVersionId: 111
            )
        ]

        let responseData = try JSONEncoder().encode(LanguagesResponse(data: expectedLanguages))
        var capturedRequest: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }

        let languages = try await YouVersionAPI.Languages.languages(country: "US", session: session)

        #expect(languages.count == 1)
        #expect(languages[0].id == "en")
        
        let request = try #require(capturedRequest)
        #expect(request.url?.absoluteString.contains("country=US") == true)
    }

    @MainActor
    @Test func languagesUnauthorizedThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: LanguageAPIError.notPermitted) {
            _ = try await YouVersionAPI.Languages.languages(session: session)
        }
    }

    @MainActor
    @Test func languagesUnexpectedStatusThrowsCannotDownload() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: LanguageAPIError.cannotDownload) {
            _ = try await YouVersionAPI.Languages.languages(session: session)
        }
    }

    @MainActor
    @Test func languagesInvalidResponseThrows() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        }

        await #expect(throws: LanguageAPIError.invalidResponse) {
            _ = try await YouVersionAPI.Languages.languages(session: session)
        }
    }

    @MainActor
    @Test func languagesMalformedJSONThrows() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let malformedJSON = "{ invalid json }".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (malformedJSON, response)
        }

        await #expect(throws: DecodingError.self) {
            _ = try await YouVersionAPI.Languages.languages(session: session)
        }
    }

    @MainActor
    @Test func languagesEmptyResponseReturnsEmptyArray() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let emptyResponse = LanguagesResponse(data: [])
        let responseData = try JSONEncoder().encode(emptyResponse)

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }

        let languages = try await YouVersionAPI.Languages.languages(session: session)
        #expect(languages.isEmpty)
    }

    // Helper struct for encoding test responses
    private struct LanguagesResponse: Encodable {
        let data: [LanguageOverview]
    }
}
