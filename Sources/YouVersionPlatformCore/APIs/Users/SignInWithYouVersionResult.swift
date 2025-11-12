import Foundation

public struct SignInWithYouVersionResult: Sendable {
    public let accessToken: String?
    public let permissions: [SignInWithYouVersionPermission]
    public let errorMsg: String?
    public let yvpUserId: String?
    
    public init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw URLError(.badServerResponse)
        }
        let status = queryItems.first(where: { $0.name == "status" })?.value
        let userId = queryItems.first(where: { $0.name == "yvp_user_id" })?.value
        let latValue = queryItems.first(where: { $0.name == "lat" })?.value
        let grants = queryItems.first(where: { $0.name == "grants" })?.value
        let perms = grants?
            .split(separator: ",")
            .compactMap { SignInWithYouVersionPermission(rawValue: String($0)) }
        ?? []

        if status == "success", let latValue, let userId {
            accessToken = latValue
            permissions = perms
            errorMsg = nil
            yvpUserId = userId
        } else if status == "canceled" {
            accessToken = nil
            permissions = []
            errorMsg = nil
            yvpUserId = nil
        } else {
            accessToken = nil
            permissions = []
            errorMsg = url.query()
            yvpUserId = nil
        }
    }
}
