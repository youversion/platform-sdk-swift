import Foundation
import Testing
@testable import YouVersionPlatformCore

@Suite struct UsersModelsTests {

    @Test func permissionRawValuesAndDescription() throws {
        #expect(SignInWithYouVersionPermission.openid.rawValue == "openid")
        #expect(SignInWithYouVersionPermission.profile.rawValue == "profile")
        #expect(SignInWithYouVersionPermission.email.rawValue == "email")
        #expect(SignInWithYouVersionPermission(rawValue: "notes") == nil)
        #expect(SignInWithYouVersionPermission.allCases == [.openid, .profile, .email])
    }

    @Test func decodingUnknownPermissionValueDoesNotThrow() throws {
        let data = Data(#""future-permission""#.utf8)

        _ = try JSONDecoder().decode(SignInWithYouVersionPermission.self, from: data)
    }

    @Test func userInfoAvatarUrlFormatting() {
        let info = YouVersionUserInfo(firstName: nil, lastName: nil, userId: nil, avatarUrlFormat: "//cdn.example.com/u_{width}x{height}.png")
        let url = info.avatarUrl
        #expect(url?.absoluteString == "https://cdn.example.com/u_200x200.png")
    }
}
