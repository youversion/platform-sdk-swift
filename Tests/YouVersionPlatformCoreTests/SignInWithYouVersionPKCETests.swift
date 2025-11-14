import Foundation
import Testing
@testable import YouVersionPlatformCore

@Suite struct SignInWithYouVersionPKCETests {

    @MainActor
    @Test func makeAuthorizationRequestIncludesVerifierAndQueryItems() throws {
        let redirectURL = URL(string: "youversionauth://callback")!

        let request = try SignInWithYouVersionPKCEAuthorizationRequestBuilder.make(
            appKey: "test-app",
            permissions: [.bibles, .highlights],
            redirectURL: redirectURL
        )

        #expect(!request.parameters.codeVerifier.isEmpty)
        #expect(!request.parameters.codeChallenge.isEmpty)
        #expect(!request.parameters.state.isEmpty)
        #expect(!request.parameters.nonce.isEmpty)

        guard let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false),
              let queryItemsArray = components.queryItems else {
            Issue.record("Failed to build URL components for authorization URL")
            return
        }

        let queryItems = Dictionary(uniqueKeysWithValues: queryItemsArray.map { ($0.name, $0.value ?? "") })

        #expect(components.path == "/auth/authorize")
        #expect(queryItems["client_id"] == "test-app")
        #expect(queryItems["response_type"] == "code")
        #expect(queryItems["code_challenge_method"] == "S256")
        #expect(queryItems["code_challenge"] == request.parameters.codeChallenge)
        #expect(queryItems["state"] == request.parameters.state)
        #expect(queryItems["nonce"] == request.parameters.nonce)
        #expect(queryItems["scope"]?.contains("bibles") == true)
        #expect(queryItems["scope"]?.contains("highlights") == true)
        #expect(queryItems["redirect_uri"] == redirectURL.absoluteString)
    }
}

