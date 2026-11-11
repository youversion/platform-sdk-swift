import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

struct APIRequestDiagnosticsTests {
    @Test
    func failureIncludesEndpointStatusServerReasonAndCorrelationWithoutSecrets() throws {
        var request = URLRequest(url: URL(string: "https://example.com/v1-beta/notes?app_key=query-secret&page_size=25")!)
        request.httpMethod = "POST"
        request.setValue("Bearer credential-secret", forHTTPHeaderField: "Authorization")
        request.setValue("app-secret", forHTTPHeaderField: "x-yvp-app-key")
        request.httpBody = Data("""
        {"content":"Private note text","request_id":"00000000-0000-4000-8000-000000000001"}
        """.utf8)
        let body = Data("""
        {"fault":{"faultstring":"Invalid app-secret credential-secret query-secret","detail":{"errorcode":"oauth.v2.InvalidApiKeyForGivenResource"}},
         "input":{"content":"Private note text"},"access_token":"server-secret"}
        """.utf8)
        let response = try #require(HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: ["x-request-id": "server-request"]))
        let summary = APIRequestDiagnostics.responseSummary(request, data: body, response: response)
        #expect(summary.contains("HTTP 403"))
        #expect(summary.contains("POST https://example.com/v1-beta/notes"))
        #expect(summary.contains("page_size=25"))
        #expect(summary.contains("request_id=00000000-0000-4000-8000-000000000001"))
        #expect(summary.contains("x-request-id=server-request"))
        #expect(summary.contains("oauth.v2.InvalidApiKeyForGivenResource"))
        for secret in ["app-secret", "credential-secret", "query-secret", "server-secret", "Private note text"] {
            #expect(!summary.contains(secret))
        }
    }

    @Test
    func successfulAuthenticationResponsesNeverLogBody() throws {
        let request = URLRequest(url: URL(string: "https://example.com/auth/token")!)
        let response = try #require(HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil))
        let summary = APIRequestDiagnostics.responseSummary(request, data: Data("{\"access_token\":\"secret-response-token\"}".utf8), response: response)
        #expect(summary.contains("HTTP 200"))
        #expect(!summary.contains("secret-response-token"))
        #expect(!summary.contains("body="))
    }

    @Test(arguments: [true, false])
    func authenticationCredentialsEchoedInErrorMessagesAreRedacted(jsonBody: Bool) throws {
        var request = URLRequest(url: URL(string: "https://example.com/auth/token")!)
        request.httpBody = Data((jsonBody ? "{\"refresh_token\":\"private-refresh-secret\"}" : "refresh_token=private-refresh-secret&grant_type=refresh_token").utf8)
        let response = try #require(HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil))
        let body = Data("{\"error\":\"invalid_grant\",\"error_description\":\"Bad private-refresh-secret\"}".utf8)
        let summary = APIRequestDiagnostics.responseSummary(request, data: body, response: response)
        #expect(summary.contains("invalid_grant"))
        #expect(!summary.contains("private-refresh-secret"))
    }

    @Test
    func unstructuredBodiesAreOmittedAndStructuredErrorsAreBounded() throws {
        let request = URLRequest(url: URL(string: "https://example.com/v1-beta/notes")!)
        let response = try #require(HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: nil, headerFields: nil))
        let summary = APIRequestDiagnostics.responseSummary(request, data: Data(String(repeating: "x", count: 6000).utf8), response: response)
        #expect(summary.contains("non-JSON error body omitted"))
        #expect(!summary.contains(String(repeating: "x", count: 100)))
        let largeJSON = try JSONSerialization.data(withJSONObject: ["message": String(repeating: "x", count: 6000)])
        let structured = APIRequestDiagnostics.responseSummary(request, data: largeJSON, response: response)
        #expect(structured.contains("[truncated]"))
        #expect(structured.count < 4500)
        struct Payload: Decodable { let id: String }
        do {
            _ = try JSONDecoder().decode(Payload.self, from: Data("{}".utf8))
            Issue.record("Expected missing id")
        } catch {
            #expect(APIRequestDiagnostics.errorSummary(error).contains("missing id at $"))
        }
    }

    @Test
    func credentialReplacementDoesNotCorruptJSONFieldNames() throws {
        var request = URLRequest(url: URL(string: "https://example.com/resource")!)
        request.setValue("x", forHTTPHeaderField: "x-api-key")
        let response = try #require(HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil))
        let body = Data("{\"explanation\":\"example of x\",\"message\":\"x\"}".utf8)
        let summary = APIRequestDiagnostics.responseSummary(request, data: body, response: response)
        #expect(summary.contains("\"explanation\":\"example of [redacted]\""))
        #expect(summary.contains("\"message\":\"[redacted]\""))
    }

    @Test
    func lowercaseBearerCredentialsAreRedactedWhenEchoed() throws {
        var request = URLRequest(url: URL(string: "https://example.com/resource")!)
        request.setValue("bearer private-token", forHTTPHeaderField: "Authorization")
        let response = try #require(HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil))
        let body = Data("{\"message\":\"Invalid private-token\"}".utf8)
        let summary = APIRequestDiagnostics.responseSummary(request, data: body, response: response)
        #expect(!summary.contains("private-token"))
    }

    @Test
    func sharedTransportPreservesHTTPFailuresAndThrownNetworkErrors() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let request = URLRequest(url: URL(string: "https://example.com/v1-beta/notes")!)
        HTTPMocking.setHandler(token: token) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (Data("failure".utf8), response)
        }
        let (data, response) = try await YouVersionAPI.response(for: request, session: session)
        #expect(data == Data("failure".utf8))
        #expect((response as? HTTPURLResponse)?.statusCode == 403)
        HTTPMocking.setHandler(token: token) { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: URLError.self) {
            _ = try await YouVersionAPI.response(for: request, session: session)
        }
        #expect(APIRequestDiagnostics.errorSummary(URLError(.notConnectedToInternet)).contains("-1009"))
    }
}
