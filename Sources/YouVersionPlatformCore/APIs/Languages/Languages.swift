import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct LanguageOverview: Codable, Sendable, Equatable {
    public let id: String
    public let language: String
    public let script: String?
    public let scriptName: String?
    public let aliases: [String]
    public let displayNames: [String: String]
    public let scripts: [String]
    public let variants: [String]
    public let countries: [String]
    public let textDirection: String
    public let defaultBibleVersionId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case language
        case script
        case scriptName = "script_name"
        case aliases
        case displayNames = "display_names"
        case scripts
        case variants
        case countries
        case textDirection = "text_direction"
        case defaultBibleVersionId = "default_bible_version_id"
    }

    public init(id: String, language: String, script: String? = nil, scriptName: String? = nil, aliases: [String] = [], displayNames: [String: String] = [:], scripts: [String] = [], variants: [String] = [], countries: [String] = [], textDirection: String = "ltr", defaultBibleVersionId: Int? = nil) {
        self.id = id
        self.language = language
        self.script = script
        self.scriptName = scriptName
        self.aliases = aliases
        self.displayNames = displayNames
        self.scripts = scripts
        self.variants = variants
        self.countries = countries
        self.textDirection = textDirection
        self.defaultBibleVersionId = defaultBibleVersionId
    }

    public static func == (lhs: LanguageOverview, rhs: LanguageOverview) -> Bool {
        lhs.id == rhs.id
    }
}

public extension YouVersionAPI {
    enum Languages {

        /// Retrieves a list of languages supported in the Platform.
        ///
        /// This function fetches language overviews from the YouVersion Platform API.
        /// A valid `YouVersionPlatformConfiguration.appKey` must be set for the request to succeed.
        ///
        /// - Parameters:
        ///   - country: An optional country code for filtering languages. If provided, only languages
        ///     used in that country will be returned.
        ///   - session: The URLSession used to perform the request. Defaults to `URLSession.shared`.
        /// - Returns: An array of LanguageOverview objects.
        public static func languages(country: String? = nil, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> [LanguageOverview] {
            guard let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken else {
                throw YouVersionAPIError.missingAuthentication
            }
            guard let url = URLBuilder.languagesURL(country: country, pageSize: 999) else {
                throw URLError(.badURL)
            }

            let request = YouVersionAPI.buildRequest(url: url, accessToken: accessToken, session: session)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("unexpected response type")
                throw YouVersionAPIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                print("error 401: unauthorized. Check your appKey")
                throw YouVersionAPIError.notPermitted
            }

            guard httpResponse.statusCode == 200 else {
                print("error in languages: \(httpResponse.statusCode)")
                throw YouVersionAPIError.cannotDownload
            }

            let responseObject = try JSONDecoder().decode(LanguagesResponse.self, from: data)
            return responseObject.data
        }

        private struct LanguagesResponse: Decodable {
            let data: [LanguageOverview]
        }
    }
}
