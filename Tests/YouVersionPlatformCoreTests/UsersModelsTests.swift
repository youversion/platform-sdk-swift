import Foundation
import Testing
@testable import YouVersionPlatformCore

@Suite struct UsersModelsTests {

    @Test func signInResultParsesSuccess() throws {
        let url = URL(string: "youversionauth://callback?status=success&yvp_user_id=U123&lat=abc123&grants=bibles,highlights,bible_activity")!
        let result = try SignInWithYouVersionResult(url: url)
        #expect(result.accessToken == "abc123")
        #expect(result.yvpUserId == "U123")
        #expect(Set(result.permissions) == Set([.bibles, .highlights, .bibleActivity]))
        #expect(result.errorMsg == nil)
    }

    @Test func signInResultParsesCanceled() throws {
        let url = URL(string: "youversionauth://callback?status=canceled")!
        let result = try SignInWithYouVersionResult(url: url)
        #expect(result.accessToken == nil)
        #expect(result.yvpUserId == nil)
        #expect(result.permissions.isEmpty)
        #expect(result.errorMsg == nil)
    }

    @Test func signInResultParsesError() throws {
        let url = URL(string: "youversionauth://callback?status=error&message=bad%20stuff")!
        let result = try SignInWithYouVersionResult(url: url)
        #expect(result.accessToken == nil)
        #expect(result.yvpUserId == nil)
        #expect(result.permissions.isEmpty)
        #expect(result.errorMsg?.contains("status=error") == true)
    }

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
