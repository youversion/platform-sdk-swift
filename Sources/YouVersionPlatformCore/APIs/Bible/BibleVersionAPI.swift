import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    enum Bible {}
}

public extension YouVersionAPI.Bible {

    static func version(versionId: Int, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> BibleVersion {
        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken

        async let metadata = basicVersion(versionId: versionId, accessToken: accessToken, session: session)
        async let index = versionIndex(versionId: versionId, accessToken: accessToken, session: session)

        return try await BibleVersion(
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
            textDirection: index.text_direction,
        )
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
    static func basicVersion(versionId: Int, accessToken: String?, session: URLSession = .shared) async throws -> BibleVersion {
        let data = try await YouVersionAPI.commonFetch(
            url: URLBuilder.versionURL(versionId: versionId),
            accessToken: accessToken,
            session: session
        )
        let responseObject = try JSONDecoder().decode(BibleVersion.self, from: data)
        return responseObject
    }

    private static func versionBooks(versionId: Int, accessToken: String?, session: URLSession = .shared) async throws -> [BibleBook] {
        struct BibleVersionBooksResponse: Codable {
            let data: [BibleBook]
        }

        let data = try await YouVersionAPI.commonFetch(
            url: URLBuilder.versionBooksURL(versionId: versionId),
            accessToken: accessToken,
            session: session
        )
        let response = try JSONDecoder().decode(BibleVersionBooksResponse.self, from: data)
        return response.data
    }

    private static func versionChapters(versionId: Int, book: String, accessToken: String?, session: URLSession = .shared) async throws -> [BibleChapter] {
        struct BibleVersionChaptersResponse: Codable {
            let data: [BibleChapter]
        }

        let data = try await YouVersionAPI.commonFetch(
            url: URLBuilder.versionBookChaptersURL(versionId: versionId, book: book),
            accessToken: accessToken,
            session: session
        )
        let response = try JSONDecoder().decode(BibleVersionChaptersResponse.self, from: data)
        return response.data
    }

    private static func versionIndex(versionId: Int, accessToken: String?, session: URLSession = .shared) async throws -> BibleVersionIndex {
        struct BibleVersionChaptersResponse: Codable {
            let data: [BibleChapter]
        }

        let data = try await YouVersionAPI.commonFetch(
            url: URLBuilder.versionIndexURL(versionId: versionId),
            accessToken: accessToken,
            session: session
        )
        let response = try JSONDecoder().decode(BibleVersionIndex.self, from: data)
        return response
    }

    // MARK: - Chapter Content

    /// Fetches the content of a single Bible chapter from the server.
    static func chapter(reference: BibleReference, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> String {
        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken
        guard let url = URLBuilder.passageURL(reference: reference, format: "html") else {
            throw URLError(.badURL)
        }

        let request = YouVersionAPI.buildRequest(url: url, accessToken: accessToken, session: session)
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

        return content
    }
    
    /// Fetches the html content of the "intro" (introductory material) for a book from the server.
    static func introMaterial(versionId: Int, passageId: String, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> String {
        let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken
        let data = try await YouVersionAPI.commonFetch(
            url: URLBuilder.passageIntroURL(versionId: versionId, passageId: passageId),
            accessToken: accessToken,
            session: session
        )
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let json = object as? [String: Any],
              let content = json["content"] as? String else {
            throw YouVersionAPIError.invalidDownload
        }

        return content
    }

    // MARK: - utility structs

    private struct BibleVersionIndex: Codable {
        let text_direction: String?
        let books: [BibleBook]?
    }
}
