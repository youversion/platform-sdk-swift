import Foundation
import Testing
@testable import YouVersionPlatformCore

@Suite struct UsersModelsTests {

    @Test func permissionRawValuesAndDescription() {
        #expect(SignInWithYouVersionPermission.bibles.rawValue == "bibles")
        #expect(SignInWithYouVersionPermission.highlights.rawValue == "highlights")
        #expect(SignInWithYouVersionPermission.votd.rawValue == "votd")
        #expect(SignInWithYouVersionPermission.demographics.rawValue == "demographics")
        #expect(SignInWithYouVersionPermission.bibleActivity.rawValue == "bible_activity")
        #expect(SignInWithYouVersionPermission.bibleActivity.description == "bible_activity")
    }

    @Test func userInfoAvatarUrlFormatting() {
        let info = YouVersionUserInfo(firstName: nil, lastName: nil, userId: nil, avatarUrlFormat: "//cdn.example.com/u_{width}x{height}.png")
        let url = info.avatarUrl
        #expect(url?.absoluteString == "https://cdn.example.com/u_200x200.png")
    }
}
