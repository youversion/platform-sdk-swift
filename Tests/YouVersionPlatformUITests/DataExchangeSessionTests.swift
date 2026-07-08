#if canImport(AuthenticationServices)
import Foundation
import Testing
@testable import YouVersionPlatformUI

@Suite struct DataExchangeSessionTests {

    @Test func grantedStatusReturnsGrantedPermissions() throws {
        let url = try #require(URL(string: "youversionauth://callback?data_exchange_status=granted&granted_permissions=highlights"))

        let permissions = DataExchangeSession.grantedPermissions(from: url)

        #expect(permissions == ["highlights"])
    }

    @Test func multipleGrantedPermissionsArePreserved() throws {
        let url = try #require(URL(string: "youversionauth://callback?data_exchange_status=granted&granted_permissions=highlights&granted_permissions=notes"))

        let permissions = DataExchangeSession.grantedPermissions(from: url)

        #expect(permissions == ["highlights", "notes"])
    }

    @Test func commaAndSpaceSeparatedGrantedPermissionsArePreserved() throws {
        let url = try #require(URL(string: "youversionauth://callback?data_exchange_status=granted&granted_permissions=highlights,notes%20bookmarks"))

        let permissions = DataExchangeSession.grantedPermissions(from: url)

        #expect(permissions == ["highlights", "notes", "bookmarks"])
    }

    @Test func missingStatusReturnsNoGrantedPermissions() throws {
        let url = try #require(URL(string: "youversionauth://callback"))

        let permissions = DataExchangeSession.grantedPermissions(from: url)

        #expect(permissions.isEmpty)
    }

    @Test func unknownStatusReturnsNoGrantedPermissions() throws {
        let url = try #require(URL(string: "youversionauth://callback?data_exchange_status=needs_review&granted_permissions=highlights"))

        let permissions = DataExchangeSession.grantedPermissions(from: url)

        #expect(permissions.isEmpty)
    }

}

#endif
