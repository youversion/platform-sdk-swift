import Foundation
import Testing
@testable import YouVersionPlatformCore

@Suite struct UsersModelsTests {

    @Test func permissionRawValuesAndDescription() throws {
        #expect(SignInWithYouVersionPermission.openid.rawValue == "openid")
        #expect(SignInWithYouVersionPermission.profile.rawValue == "profile")
        #expect(SignInWithYouVersionPermission.email.rawValue == "email")
        #expect(SignInWithYouVersionPermission.highlights.rawValue == "highlights")
        let permission = try #require(SignInWithYouVersionPermission(rawValue: "notes"))
        #expect(permission == .unknown("notes"))
        #expect(permission.rawValue == "notes")
        #expect(SignInWithYouVersionPermission.allCases == [.openid, .profile, .email, .highlights])
    }

    @Test func userInfoAvatarUrlFormatting() {
        let info = YouVersionUserInfo(firstName: nil, lastName: nil, userId: nil, avatarUrlFormat: "//cdn.example.com/u_{width}x{height}.png")
        let url = info.avatarUrl
        #expect(url?.absoluteString == "https://cdn.example.com/u_200x200.png")
    }
}
