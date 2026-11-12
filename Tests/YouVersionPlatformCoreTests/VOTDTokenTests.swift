import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import YouVersionPlatformCore

extension ConfigurationStateTests {
    @Suite(.serialized)
    struct VOTDTokenTests {
        /// Refreshes expired default credentials for day and calendar calls while preserving explicit tokens.
        @MainActor
        @Test(arguments: [false, true], [false, true])
        func tokenResolution(isCalendar: Bool, usesExplicitToken: Bool) async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            YouVersionPlatformConfiguration.configure(appKey: "votd-refresh-tests")
            defer {
                YouVersionPlatformConfiguration.clearAuthTokens()
                YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            }
            YouVersionPlatformConfiguration.saveAuthData(
                accessToken: "expired-votd-token", refreshToken: "votd-refresh-token", idToken: nil,
                expiryDate: Date(timeIntervalSinceNow: -60)
            )
            let (session, token) = HTTPMocking.makeSession()
            defer { HTTPMocking.clear(token: token) }
            let expectedToken = usesExplicitToken ? "explicit-votd-token" : "refreshed-votd-token"
            let resourceJSON = isCalendar ? "{\"data\":[]}" : "{\"day\":1,\"passage_id\":\"JHN.3.16\"}"
            HTTPMocking.setHandler(token: token) { @Sendable request in
                let data: Data
                if request.url?.path == "/auth/token" {
                    #expect(!usesExplicitToken)
                    #expect(request.httpMethod == "POST")
                    data = Data("""
                    {"access_token":"refreshed-votd-token","refresh_token":"new-votd-refresh","expires_in":"7200","scope":""}
                    """.utf8)
                } else {
                    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(expectedToken)")
                    data = Data(resourceJSON.utf8)
                }
                return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            let accessToken = usesExplicitToken ? expectedToken : nil
            if isCalendar {
                _ = try await YouVersionAPI.VOTD.versesOfTheDay(accessToken: accessToken, session: session)
            } else {
                _ = try await YouVersionAPI.VOTD.verseOfTheDay(
                    dayOfYear: 1, languageRanges: ["en"], accessToken: accessToken, session: session
                )
            }
            #expect(YouVersionPlatformConfiguration.accessToken == (usesExplicitToken ? "expired-votd-token" : expectedToken))
        }
    }
}
