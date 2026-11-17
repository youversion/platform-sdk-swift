import Foundation
import Testing
@testable import YouVersionPlatformCore

extension ConfigurationStateTests {
    @MainActor
    @Suite(.serialized)
    struct AuthenticationChangeNotificationTests {
        @Test(arguments: [true, false])
        func reauthorizationNotifiesAfterStoringChangedCredentialsOrPermissions(replacesToken: Bool) {
            let original = YouVersionPlatformConfiguration.authData
            defer {
                YouVersionPlatformConfiguration.clearAuthTokens()
                if let original {
                    YouVersionPlatformConfiguration.saveAuthData(
                        accessToken: original.accessToken, refreshToken: original.refreshToken,
                        idToken: original.idToken, expiryDate: original.expiryDate, permissions: original.permissionValues
                    )
                }
            }
            YouVersionPlatformConfiguration.clearAuthTokens()
            YouVersionPlatformConfiguration.saveAuthData(
                accessToken: "initial-test-access", refreshToken: nil, idToken: nil,
                expiryDate: Date().addingTimeInterval(3600), permissions: ["profile"]
            )
            let counter = NotificationCounter()
            let authorization = NotificationCenter.default.addObserver(
                forName: YouVersionPlatformConfiguration.authDataDidChangeNotification, object: nil, queue: nil
            ) { _ in
                MainActor.assumeIsolated {
                    counter.authorizationCount += 1
                    counter.hadReadAccessAtNotification = YouVersionAPI.hasPermission("read_notes")
                }
            }
            let signInState = NotificationCenter.default.addObserver(
                forName: YouVersionPlatformConfiguration.authStateDidChangeNotification, object: nil, queue: nil
            ) { _ in
                MainActor.assumeIsolated { counter.signInStateCount += 1 }
            }
            defer {
                NotificationCenter.default.removeObserver(authorization)
                NotificationCenter.default.removeObserver(signInState)
            }
            let replacementAccess = replacesToken ? "replacement-test-access" : "initial-test-access"
            let replacementPermissions = replacesToken ? ["profile"] : ["profile", "read_notes", "write_notes"]
            YouVersionPlatformConfiguration.saveAuthData(
                accessToken: replacementAccess, refreshToken: nil, idToken: nil,
                expiryDate: Date().addingTimeInterval(3600), permissions: replacementPermissions
            )
            YouVersionPlatformConfiguration.saveAuthData(
                accessToken: replacementAccess, refreshToken: nil, idToken: nil,
                expiryDate: Date().addingTimeInterval(7200), permissions: replacementPermissions
            )
            #expect(counter.authorizationCount == 1)
            #expect(counter.signInStateCount == 0)
            #expect(counter.hadReadAccessAtNotification == !replacesToken)
        }
    }

    @MainActor
    private final class NotificationCounter {
        var authorizationCount = 0
        var signInStateCount = 0
        var hadReadAccessAtNotification = false
    }
}
