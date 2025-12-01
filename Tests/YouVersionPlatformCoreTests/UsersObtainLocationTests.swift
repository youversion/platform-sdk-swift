import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct UsersObtainLocationTests {

    @MainActor
    @Test func obtainLocationSuccessReturnsRedirectLocation() async throws {
        let originalHost = YouVersionPlatformConfiguration.apiHost
        YouVersionPlatformConfiguration.apiHost = "testing.youversion.example"
        defer { YouVersionPlatformConfiguration.apiHost = originalHost }

        let expectedLocation = "youversionauth://callback?code=expected-code"

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CallbackURLProtocol.self]
        let session = URLSession(configuration: configuration)

        CallbackURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            guard url.path == "/auth/callback" else { throw URLError(.badURL) }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": expectedLocation]
            )!
            return (Data(), response)
        }
        defer {
            CallbackURLProtocol.handler = nil
        }

        let callbackURL = URL(string: "youversionauth://callback?state=test-state&code=ignored")!
        let location = try await YouVersionAPI.Users.obtainLocation(
            from: callbackURL,
            state: "test-state",
            session: session
        )

        #expect(location == expectedLocation)
    }

    @MainActor
    @Test func obtainLocationUnexpectedStatusThrowsBadServerResponse() async {
        let originalHost = YouVersionPlatformConfiguration.apiHost
        YouVersionPlatformConfiguration.apiHost = "testing.youversion.example"
        defer { YouVersionPlatformConfiguration.apiHost = originalHost }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CallbackURLProtocol.self]
        let session = URLSession(configuration: configuration)

        CallbackURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
            return (Data(), response)
        }
        defer {
            CallbackURLProtocol.handler = nil
        }

        let callbackURL = URL(string: "youversionauth://callback?state=test-state&code=ignored")!

        await #expect(throws: URLError.self) {
            _ = try await YouVersionAPI.Users.obtainLocation(
                from: callbackURL,
                state: "test-state",
                session: session
            )
        }
    }
}

private final class CallbackURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Data, URLResponse))?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == YouVersionPlatformConfiguration.apiHost
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        guard let request = task.currentRequest else { return false }
        return canInit(with: request)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (data, response) = try handler(request)
            if let httpResponse = response as? HTTPURLResponse {
                client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            } else {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

