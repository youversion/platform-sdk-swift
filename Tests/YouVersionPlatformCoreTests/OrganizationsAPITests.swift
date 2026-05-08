import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct OrganizationsAPITests {

    @MainActor
    @Test func organizationSuccessReturnsDecodedOrganization() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {
            "id": "org-123",
            "parent_organization_id": "org-000",
            "name": "Test Church",
            "description": "A test church",
            "email": "test@church.org",
            "phone": "+1-555-0100",
            "primary_language": "en",
            "website_url": "https://church.org",
            "address": "123 Main St"
        }
        """.data(using: .utf8)!
        var capturedRequest: URLRequest?

        HTTPMocking.setHandler(token: token) { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let org = try await YouVersionAPI.Organizations.organization(id: "org-123", session: session)

        #expect(org.id == "org-123")
        #expect(org.parentOrganizationId == "org-000")
        #expect(org.name == "Test Church")
        #expect(org.description == "A test church")
        #expect(org.email == "test@church.org")
        #expect(org.phone == "+1-555-0100")
        #expect(org.primaryLanguage == "en")
        #expect(org.websiteUrl == "https://church.org")
        #expect(org.address == "123 Main St")
        let req = try #require(capturedRequest)
        #expect(req.url?.absoluteString.contains("org-123") == true)
    }

    @MainActor
    @Test func organizationSuccessWithNullableFieldsAbsent() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        let json = """
        {"id": "org-456"}
        """.data(using: .utf8)!

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let org = try await YouVersionAPI.Organizations.organization(id: "org-456", session: session)

        #expect(org.id == "org-456")
        #expect(org.parentOrganizationId == nil)
        #expect(org.name == nil)
        #expect(org.description == nil)
        #expect(org.email == nil)
        #expect(org.phone == nil)
        #expect(org.primaryLanguage == nil)
        #expect(org.websiteUrl == nil)
        #expect(org.address == nil)
    }

    @MainActor
    @Test func organizationUnauthorizedThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.Organizations.organization(id: "org-123", session: session)
        }
    }

    @MainActor
    @Test func organizationForbiddenThrowsNotPermitted() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.notPermitted) {
            _ = try await YouVersionAPI.Organizations.organization(id: "org-123", session: session)
        }
    }

    @MainActor
    @Test func organizationServerErrorThrowsCannotDownload() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.cannotDownload) {
            _ = try await YouVersionAPI.Organizations.organization(id: "org-123", session: session)
        }
    }

    @MainActor
    @Test func organizationInvalidResponseThrows() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (Data(), response)
        }

        await #expect(throws: YouVersionAPIError.invalidResponse) {
            _ = try await YouVersionAPI.Organizations.organization(id: "org-123", session: session)
        }
    }

    @MainActor
    @Test func organizationMalformedJSONThrowsBadServerResponse() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            let malformed = "{ bad json }".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (malformed, response)
        }

        await #expect(throws: URLError.self) {
            _ = try await YouVersionAPI.Organizations.organization(id: "org-123", session: session)
        }
    }
}
