import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import YouVersionPlatformCore

extension ConfigurationStateTests {
    @Suite struct URLRequestYouVersionTests {
        
        @Test func sdkVersionHeaderIsSetWhenAppKeyConfigured() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: "test-app")
            
            let url = try #require(URL(string: "https://api.youversion.com/v1/bibles/1"))
            let request = URLRequest.youVersion(url)
            
            #expect(request.value(forHTTPHeaderField: "x-yvp-app-key") == "test-app")
            #expect(request.value(forHTTPHeaderField: "x-yvp-sdk") == "SwiftSDK=\(SDKVersion.current)")
            
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
        
        @Test func sdkVersionHeaderIsAbsentWhenAppKeyNotConfigured() async throws {
            let originalAppKey = YouVersionPlatformConfiguration.appKey
            await YouVersionPlatformConfiguration.configure(appKey: nil)
            
            let url = try #require(URL(string: "https://api.youversion.com/v1/bibles/1"))
            let request = URLRequest.youVersion(url)
            
            #expect(request.value(forHTTPHeaderField: "x-yvp-app-key") == nil)
            #expect(request.value(forHTTPHeaderField: "x-yvp-sdk") == nil)
            
            await YouVersionPlatformConfiguration.configure(appKey: originalAppKey)
        }
    }
}
