import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    enum Bible {}
}

extension YouVersionAPI.Bible {

    public static func version(withId versionId: Int, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> BibleVersion {
        try await versionResponse(withId: versionId, accessToken: providedToken, session: session).value
    }

    static func versionResponse(
        withId versionId: Int,
        accessToken providedToken: String? = nil,
        session: URLSession = .shared
    ) async throws -> CachedBibleContent<BibleVersion> {
        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken

        async let metadataTask = metadataResponseForVersion(
            withId: versionId,
            accessToken: accessToken,
            session: session
        )
        async let indexTask = indexResponseForVersion(
            withId: versionId,
            accessToken: accessToken,
            session: session
        )

        let (metadataResponse, indexResponse) = try await (metadataTask, indexTask)
        let metadata = metadataResponse.value
        let index = indexResponse.value

        return CachedBibleContent(
            value: BibleVersion(
                id: metadata.id,
                abbreviation: metadata.abbreviation,
                promotionalContent: metadata.promotionalContent,
                copyright: metadata.copyright,
                languageTag: metadata.languageTag,
                localizedAbbreviation: metadata.localizedAbbreviation,
                localizedTitle: metadata.localizedTitle,
                readerFooter: metadata.readerFooter,
                readerFooterUrl: metadata.readerFooterUrl,
                title: metadata.title,
                organizationId: metadata.organizationId,
                bookCodes: metadata.bookCodes,
                books: index.books,
                textDirection: index.textDirection,
            ),
            expirationDate: [metadataResponse.expirationDate, indexResponse.expirationDate]
                .compactMap { $0 }
                .min()
        )
    }

    @available(*, deprecated, renamed: "version(withId:accessToken:session:)")
    public static func version(versionId: Int, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> BibleVersion {
        try await version(withId: versionId, accessToken: providedToken, session: session)
    }

    /// Retrieves metadata for a specific Bible version from the server.
    ///
    /// This function fetches metadata for the Bible version identified by `versionId`.
    /// The request requires a valid `YouVersionPlatformConfiguration.appKey` to be set.
    ///
    /// - Parameters:
    ///   - versionId: The identifier of the Bible version to fetch metadata for.
    ///   - session: The URLSession used to perform the request. Defaults to `URLSession.shared`.
    /// - Returns: The raw `Data` containing the version metadata.
    ///
    /// - Throws:
    ///   - `URLError` if the URL is invalid.
    ///   - `YouVersionAPIError.notPermitted` if the app key is invalid or lacks permission.
    ///   - `YouVersionAPIError.cannotDownload` if the server returns an error response.
    ///   - `YouVersionAPIError.invalidResponse` if the server response is not valid.
    public static func metadataForVersion(withId versionId: Int, accessToken: String?, session: URLSession = .shared) async throws -> BibleVersion {
        try await metadataResponseForVersion(withId: versionId, accessToken: accessToken, session: session).value
    }

    private static func metadataResponseForVersion(
        withId versionId: Int,
        accessToken: String?,
        session: URLSession
    ) async throws -> CachedBibleContent<BibleVersion> {
        guard let url = URLBuilder.versionURL(versionId: versionId) else {
            throw URLError(.badURL)
        }
        let response = try await YouVersionAPI.responseData(at: url, accessToken: accessToken, session: session)
        return CachedBibleContent(
            value: try JSONDecoder().decode(BibleVersion.self, from: response.value),
            expirationDate: response.expirationDate
        )
    }

    @available(*, deprecated, renamed: "metadataForVersion(withId:accessToken:session:)")
    public static func basicVersion(versionId: Int, accessToken: String?, session: URLSession = .shared) async throws -> BibleVersion {
        try await metadataForVersion(withId: versionId, accessToken: accessToken, session: session)
    }

    private static func indexResponseForVersion(
        withId versionId: Int,
        accessToken: String?,
        session: URLSession
    ) async throws -> CachedBibleContent<BibleVersionIndex> {
        struct BibleVersionChaptersResponse: Codable {
            let data: [BibleChapter]
        }

        guard let url = URLBuilder.versionIndexURL(versionId: versionId) else {
            throw URLError(.badURL)
        }
        let response = try await YouVersionAPI.responseData(at: url, accessToken: accessToken, session: session)
        return CachedBibleContent(
            value: try JSONDecoder().decode(BibleVersionIndex.self, from: response.value),
            expirationDate: response.expirationDate
        )
    }

    // MARK: - Chapter Content

    /// Fetches the content of a single Bible chapter from the server.
    public static func chapter(reference: BibleReference, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> String {
        try await chapterResponse(reference: reference, accessToken: providedToken, session: session).value
    }

    static func chapterResponse(
        reference: BibleReference,
        accessToken providedToken: String? = nil,
        session: URLSession = .shared
    ) async throws -> CachedBibleContent<String> {
        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken
        guard let url = URLBuilder.passageURL(reference: reference, format: "html") else {
            throw URLError(.badURL)
        }

        let request = YouVersionAPI.urlRequest(with: url, accessToken: accessToken, session: session)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            YouVersionPlatformLogger.error("unexpected response type", category: "BibleVersion")
            throw YouVersionAPIError.invalidResponse
        }

        if httpResponse.statusCode == 403 {
            YouVersionPlatformLogger.error("Not permitted; check your appKey and its entitlements.", category: "BibleVersion")
            throw YouVersionAPIError.notPermitted
        }

        guard httpResponse.statusCode == 200 else {
            YouVersionPlatformLogger.error("error \(httpResponse.statusCode) while fetching an html chapter", category: "BibleVersion")
            throw YouVersionAPIError.cannotDownload
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let json = object as? [String: Any],
              let content = json["content"] as? String else {
            throw YouVersionAPIError.invalidDownload
        }

        return CachedBibleContent(
            value: content,
            expirationDate: httpResponse.cacheExpirationDate()
        )
    }
    
    /// Fetches the html content of the "intro" (introductory material) for a book from the server.
    public static func introMaterial(versionId: Int, passageId: String, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> String {
        guard let url = URLBuilder.passageIntroURL(versionId: versionId, passageId: passageId) else {
            throw URLError(.badURL)
        }
        
        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken
        let data = try await YouVersionAPI.data(at: url, accessToken: accessToken, session: session)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let json = object as? [String: Any],
              let content = json["content"] as? String else {
            throw YouVersionAPIError.invalidDownload
        }

        return content
    }

    // MARK: - utility structs

    private struct BibleVersionIndex: Codable {
        let textDirection: String?
        let books: [BibleBook]?

        enum CodingKeys: String, CodingKey {
            case textDirection = "text_direction"
            case books
        }
    }
}
