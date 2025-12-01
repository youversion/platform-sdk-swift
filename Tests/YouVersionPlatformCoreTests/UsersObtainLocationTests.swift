import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

@Suite(.serialized) struct UsersObtainLocationTests {

    @MainActor
    @Test func obtainLocationSuccessReturnsRedirectLocation() async throws {
        let expectedLocation = "youversionauth://callback?code=expected-code"

        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
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
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }

        HTTPMocking.setHandler(token: token) { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
            )!
            return (Data(), response)
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
