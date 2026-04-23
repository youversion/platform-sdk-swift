import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct LanguageOverview: Codable, Sendable, Equatable {
    public let id: String?
    public let language: String?
    public let script: String?
    public let scriptName: String?
    public let aliases: [String]?
    public let displayNames: [String: String?]?
    public let scripts: [String]?
    public let variants: [String]?
    public let countries: [String]?
    public let textDirection: String?
    public let defaultBibleId: Int?

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
        case defaultBibleId = "default_bible_id"
    }

    public init(id: String? = nil, language: String? = nil, script: String? = nil, scriptName: String? = nil, aliases: [String]? = nil, displayNames: [String: String]? = nil, scripts: [String]? = nil, variants: [String]? = nil, countries: [String]? = nil, textDirection: String = "ltr", defaultBibleId: Int? = nil) {
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
        self.defaultBibleId = defaultBibleId
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
        public static func languages(country: String? = nil, fields: [String] = [], accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> [LanguageOverview] {
            let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken

            var allResults: [LanguageOverview] = []
            var pageToken: String?

            repeat {
                guard let url = URLBuilder.languagesURL(
                    country: country,
                    fields: fields,
                    pageSize: (1...3).contains(fields.count) ? nil : 99,
                    pageToken: pageToken
                )
                else {
                    throw URLError(.badURL)
                }

                let request = YouVersionAPI.buildRequest(url: url, accessToken: accessToken, session: session)
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    YouVersionPlatformLogger.error("unexpected response type", category: "Languages")
                    throw YouVersionAPIError.invalidResponse
                }

                if httpResponse.statusCode == 401 {
                    YouVersionPlatformLogger.error("error 401: unauthorized. Check your appKey", category: "Languages")
                    throw YouVersionAPIError.notPermitted
                }

                guard httpResponse.statusCode == 200 else {
                    YouVersionPlatformLogger.error("error in languages: \(httpResponse.statusCode)", category: "Languages")
                    throw YouVersionAPIError.cannotDownload
                }

                let responseObject = try JSONDecoder().decode(LanguagesResponse.self, from: data)
                allResults.append(contentsOf: responseObject.data)
                pageToken = responseObject.nextPageToken
            } while pageToken != nil

            return allResults
        }

        private struct LanguagesResponse: Decodable {
            let data: [LanguageOverview]
            let nextPageToken: String?
            let totalSize: Int?

            enum CodingKeys: String, CodingKey {
                case data
                case nextPageToken = "next_page_token"
                case totalSize = "total_size"
            }
        }
    }
}
