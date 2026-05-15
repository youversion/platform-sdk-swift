#if canImport(AuthenticationServices)
import Foundation
import Testing
@testable import YouVersionPlatformUI

@Suite struct DataExchangeSessionTests {

    @Test func grantedStatusReturnsGrantedResult() throws {
        let url = try #require(URL(string: "youversionauth://callback?status=granted"))

        let result = try DataExchangeSession.requestResult(from: url)

        #expect(result == .granted)
    }

    @Test func cancelStatusReturnsCancelledResult() throws {
        let url = try #require(URL(string: "youversionauth://callback?status=cancel"))

        let result = try DataExchangeSession.requestResult(from: url)

        #expect(result == .cancelled)
    }

    @Test func missingStatusThrowsBadServerResponse() throws {
        let url = try #require(URL(string: "youversionauth://callback"))

        #expect(throws: URLError(.badServerResponse)) {
            try DataExchangeSession.requestResult(from: url)
        }
    }

    @Test func unknownStatusThrowsBadServerResponse() throws {
        let url = try #require(URL(string: "youversionauth://callback?status=denied"))

        #expect(throws: URLError(.badServerResponse)) {
            try DataExchangeSession.requestResult(from: url)
        }
    }

}

#endif
