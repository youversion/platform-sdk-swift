#if canImport(AuthenticationServices)
import Foundation
import Testing
@testable import YouVersionPlatformUI

@Suite struct DataExchangeSessionTests {

    @Test func grantedStatusReturnsGrantedResult() throws {
        let url = try #require(URL(string: "youversionauth://callback?data_exchange_status=granted&granted_permissions=highlights"))

        let result = DataExchangeSession.requestResult(from: url)

        #expect(result.status == .granted)
        #expect(result.isGranted)
        #expect(result.grantedPermissions == [.highlights])
    }

    @Test func multipleGrantedPermissionsArePreserved() throws {
        let url = try #require(URL(string: "youversionauth://callback?data_exchange_status=granted&granted_permissions=highlights&granted_permissions=notes"))

        let result = DataExchangeSession.requestResult(from: url)

        #expect(result.status == .granted)
        #expect(result.grantedPermissions == [.highlights, .unknown("notes")])
    }

    @Test func missingStatusReturnsEmptyStatus() throws {
        let url = try #require(URL(string: "youversionauth://callback"))

        let result = DataExchangeSession.requestResult(from: url)

        #expect(result.status == .missing)
        #expect(result.grantedPermissions.isEmpty)
        #expect(!result.isGranted)
    }

    @Test func unknownStatusIsPreserved() throws {
        let url = try #require(URL(string: "youversionauth://callback?data_exchange_status=needs_review&granted_permissions=highlights"))

        let result = DataExchangeSession.requestResult(from: url)

        #expect(result.status == .unknown("needs_review"))
        #expect(result.grantedPermissions == [.highlights])
        #expect(!result.isGranted)
    }

}

#endif
