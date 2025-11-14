import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct Organization: Codable, Sendable, Equatable {
    public let id: String
    public let parentOrganizationId: String?
    public let name: String?
    public let description: String?
    public let email: String?
    public let phone: String?
    public let primaryLanguage: String?
    public let websiteUrl: String?
    public let address: String?

    enum CodingKeys: String, CodingKey {
        case id
        case parentOrganizationId = "parent_organization_id"
        case name
        case description
        case email
        case phone
        case primaryLanguage = "primary_language"
        case websiteUrl = "website_url"
        case address
    }

    public init(id: String, parentOrganizationId: String?, name: String?, description: String?, email: String?, phone: String?, primaryLanguage: String?, websiteUrl: String?, address: String?) {
        self.id = id
        self.parentOrganizationId = parentOrganizationId
        self.name = name
        self.description = description
        self.email = email
        self.phone = phone
        self.primaryLanguage = primaryLanguage
        self.websiteUrl = websiteUrl
        self.address = address
    }

    public static func == (lhs: Organization, rhs: Organization) -> Bool {
        lhs.id == rhs.id
    }
}

public extension YouVersionAPI {
    enum Organizations {

        public static func organizations(id: String, session: URLSession = .shared) async throws -> Organization {
            guard let url = URLBuilder.organizationsURL(id: id) else {
                throw URLError(.badURL)
            }
            let data = try await YouVersionAPI.commonFetch(url: url, accessToken: nil, session: session)
            guard let decodedResponse = try? JSONDecoder().decode(Organization.self, from: data) else {
                throw URLError(.badServerResponse)
            }
            return decodedResponse
        }
    }
}
