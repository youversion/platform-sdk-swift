import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

extension ConfigurationStateTests {
    @Suite struct YouVersionPlatformConfigurationTests {
        
        // MARK: - configure
        
        @Test func configureStoresAppKey() async {
            let original = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: "test-key")
            #expect(YouVersionPlatformConfiguration.appKey == "test-key")
            await YouVersionPlatformConfiguration.configure(appKey: original)
        }
        
        @Test func configureNilAppKeyStoresNil() async {
            let original = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: nil)
            #expect(YouVersionPlatformConfiguration.appKey == nil)
            await YouVersionPlatformConfiguration.configure(appKey: original)
        }
        
        @Test func configureOverridesApiHost() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            let originalApiHost = YouVersionPlatformConfiguration.apiHost
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, apiHost: "custom.example.com")
            #expect(YouVersionPlatformConfiguration.apiHost == "custom.example.com")
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, apiHost: originalApiHost)
        }
        
        @Test func configureNilApiHostKeepsExistingValue() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            let originalApiHost = YouVersionPlatformConfiguration.apiHost
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, apiHost: "first.example.com")
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, apiHost: nil)
            #expect(YouVersionPlatformConfiguration.apiHost == "first.example.com")
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, apiHost: originalApiHost)
        }
        
        @Test func configureStoresAppName() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, appName: "My App")
            #expect(YouVersionPlatformConfiguration.appName == "My App")
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
        
        @Test func configureDisablesSignIn() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, isSignInEnabled: false)
            #expect(YouVersionPlatformConfiguration.isSignInEnabled == false)
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
        
        @Test func configureDefaultsSignInToEnabled() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, isSignInEnabled: false)
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            #expect(YouVersionPlatformConfiguration.isSignInEnabled == true)
        }
        
        @Test func configureStoresSignInPromptMessage() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, signInPromptMessage: "Please sign in.")
            #expect(YouVersionPlatformConfiguration.signInPromptMessage == "Please sign in.")
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
        
        @Test func configureInstallIdIsNonNilAfterConfigure() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            #expect(YouVersionPlatformConfiguration.installId != nil)
        }
        
        @Test func configureInstallIdIsStableAcrossSubsequentCalls() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            let firstId = YouVersionPlatformConfiguration.installId
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
            #expect(YouVersionPlatformConfiguration.installId == firstId)
        }
        
        // MARK: - configureSignIn
        
        @Test func configureSignInSetsAppName() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configureSignIn(appName: "Sign In App")
            #expect(YouVersionPlatformConfiguration.appName == "Sign In App")
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
        
        @Test func configureSignInForcesSignInEnabled() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey, isSignInEnabled: false)
            await YouVersionPlatformConfiguration.configureSignIn(appName: "My App")
            #expect(YouVersionPlatformConfiguration.isSignInEnabled == true)
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
        
        @Test func configureSignInSetsPromptMessage() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configureSignIn(appName: "My App", signInPromptMessage: "Sign in to see your highlights.")
            #expect(YouVersionPlatformConfiguration.signInPromptMessage == "Sign in to see your highlights.")
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
        
        @Test func configureSignInNilPromptMessageClearsMessage() async {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configureSignIn(appName: "My App", signInPromptMessage: "Initial message")
            await YouVersionPlatformConfiguration.configureSignIn(appName: "My App", signInPromptMessage: nil)
            #expect(YouVersionPlatformConfiguration.signInPromptMessage == nil)
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
        
        // MARK: - saveAuthData / accessToken / authData / clearAuthTokens
        
        @Test func saveAuthDataPersistsAccessToken() async {
            let expiry = Date(timeIntervalSinceNow: 3600)
            await YouVersionPlatformConfiguration.saveAuthData(accessToken: "token-abc", refreshToken: "refresh-xyz", idToken: nil, expiryDate: expiry)
            #expect(YouVersionPlatformConfiguration.accessToken == "token-abc")
            await YouVersionPlatformConfiguration.clearAuthTokens()
        }
        
        @Test func authDataReturnsFullResultWhenAllTokensPresent() async {
            let expiry = Date(timeIntervalSinceNow: 3600)
            await YouVersionPlatformConfiguration.saveAuthData(
                accessToken: "access-1",
                refreshToken: "refresh-1",
                idToken: "id-1",
                expiryDate: expiry
            )
            let data = YouVersionPlatformConfiguration.authData
            #expect(data?.accessToken == "access-1")
            #expect(data?.refreshToken == "refresh-1")
            #expect(data?.idToken == "id-1")
            #expect(data?.expiryDate != nil)
            await YouVersionPlatformConfiguration.clearAuthTokens()
        }
        
        @Test func authDataIncludesNilIdTokenWhenNotStored() async {
            let expiry = Date(timeIntervalSinceNow: 3600)
            await YouVersionPlatformConfiguration.saveAuthData(accessToken: "access-1", refreshToken: "refresh-1", idToken: nil, expiryDate: expiry)
            let data = YouVersionPlatformConfiguration.authData
            #expect(data != nil)
            #expect(data?.idToken == nil)
            await YouVersionPlatformConfiguration.clearAuthTokens()
        }
        
        @Test func authDataReturnsNilWhenAccessTokenMissing() async {
            let expiry = Date(timeIntervalSinceNow: 3600)
            await YouVersionPlatformConfiguration.saveAuthData(accessToken: nil, refreshToken: "refresh-1", idToken: nil, expiryDate: expiry)
            #expect(YouVersionPlatformConfiguration.authData == nil)
            await YouVersionPlatformConfiguration.clearAuthTokens()
        }
        
        @Test func authDataReturnsNilWhenRefreshTokenMissing() async {
            let expiry = Date(timeIntervalSinceNow: 3600)
            await YouVersionPlatformConfiguration.saveAuthData(accessToken: "access-1", refreshToken: nil, idToken: nil, expiryDate: expiry)
            #expect(YouVersionPlatformConfiguration.authData == nil)
            await YouVersionPlatformConfiguration.clearAuthTokens()
        }
        
        @Test func authDataReturnsNilWhenExpiryDateMissing() async {
            await YouVersionPlatformConfiguration.saveAuthData(accessToken: "access-1", refreshToken: "refresh-1", idToken: nil, expiryDate: nil)
            #expect(YouVersionPlatformConfiguration.authData == nil)
            await YouVersionPlatformConfiguration.clearAuthTokens()
        }
        
        @Test func clearAuthTokensMakesAuthDataNil() async {
            let expiry = Date(timeIntervalSinceNow: 3600)
            await YouVersionPlatformConfiguration.saveAuthData(accessToken: "access-1", refreshToken: "refresh-1", idToken: "id-1", expiryDate: expiry)
            await YouVersionPlatformConfiguration.clearAuthTokens()
            #expect(YouVersionPlatformConfiguration.authData == nil)
            #expect(YouVersionPlatformConfiguration.accessToken == nil)
        }
        
        // MARK: - Top-level configure function
        
        @Test func topLevelConfigureFunctionSetsAppKey() async {
            let original = YouVersionPlatformConfiguration.appKey
            await configure(appKey: "top-level-key")
            #expect(YouVersionPlatformConfiguration.appKey == "top-level-key")
            await YouVersionPlatformConfiguration.configure(appKey: original)
        }
    }
}
