import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    enum Bible {}
}

public extension YouVersionAPI.Bible {

    static func version(versionId: Int, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> BibleVersion {
        guard let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken else {
            throw YouVersionAPIError.missingAuthentication
        }

        let time1 = Date()
        let basic = try await basicVersion(versionId: versionId, accessToken: accessToken, session: session)
        let time2 = Date()
        let index = try await versionIndex(versionId: versionId, accessToken: accessToken, session: session)
        let time3 = Date()

        let elapsed1 = time2.timeIntervalSince(time1)
        let elapsed2 = time3.timeIntervalSince(time2)
        print("Version fetched from the server. Times were \(String(format: "%.1f", elapsed1)) and \(String(format: "%.1f", elapsed2)) seconds.")

        var fullBooks: [BibleBook] = []
        for book in index.books ?? [] where book.chapters?.isEmpty == false {
            var chapters: [BibleChapter] = []
            // non-canonical chapters don't have verses.
            for chapter in book.chapters ?? [] where chapter.verses?.isEmpty == false {
                chapters.append(BibleChapter(bookUSFM: chapter.id, isCanonical: true, passageId: chapter.id, title: chapter.title))
            }
            let newBook = BibleBook(
                usfm: book.id,
                abbreviation: book.abbreviation,
                title: book.title,
                titleLong: nil,
                chapters: chapters
            )
            fullBooks.append(newBook)
        }
        return BibleVersion(
            id: basic.id,
            abbreviation: basic.abbreviation,
            copyrightLong: basic.copyrightLong,
            copyrightShort: basic.copyrightShort,
            languageTag: basic.languageTag,
            localizedAbbreviation: basic.localizedAbbreviation,
            localizedTitle: basic.localizedTitle,
            readerFooter: basic.readerFooter,
            readerFooterUrl: basic.readerFooterUrl,
            title: basic.title,
            bookCodes: fullBooks.compactMap { $0.usfm },
            books: fullBooks,
            textDirection: index.text_direction
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
    static func basicVersion(versionId: Int, accessToken: String, session: URLSession = .shared) async throws -> BibleVersion {
        let data = try await YouVersionAPI.commonFetch(
            url: URLBuilder.versionURL(versionId: versionId),
            accessToken: accessToken,
            session: session
        )
        let responseObject = try JSONDecoder().decode(BibleVersion.self, from: data)
        return responseObject
    }

    private static func versionBooks(versionId: Int, accessToken: String, session: URLSession = .shared) async throws -> [BibleVersionBook] {
        struct BibleVersionBooksResponse: Codable {
            let data: [BibleVersionBook]
        }

        let data = try await YouVersionAPI.commonFetch(
            url: URLBuilder.versionBooksURL(versionId: versionId),
            accessToken: accessToken,
            session: session
        )
        let response = try JSONDecoder().decode(BibleVersionBooksResponse.self, from: data)
        return response.data
    }

    private static func versionChapters(versionId: Int, book: String, accessToken: String, session: URLSession = .shared) async throws -> [BibleChapter] {
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

    private static func versionIndex(versionId: Int, accessToken: String, session: URLSession = .shared) async throws -> BibleVersionIndex {
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
        guard let accessToken = providedToken ?? YouVersionPlatformConfiguration.accessToken else {
            throw YouVersionAPIError.missingAuthentication
        }
        guard let url = URLBuilder.passageURL(reference: reference, format: "html") else {
            throw URLError(.badURL)
        }

        let request = YouVersionAPI.buildRequest(url: url, accessToken: accessToken, session: session)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("unexpected response type")
            throw YouVersionAPIError.invalidResponse
        }

        if httpResponse.statusCode == 403 {
            print("Not permitted; check your appKey and its entitlements.")
            throw YouVersionAPIError.notPermitted
        }

        guard httpResponse.statusCode == 200 else {
            print("error \(httpResponse.statusCode) while fetching an html chapter")
            throw YouVersionAPIError.cannotDownload
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let json = object as? [String: Any],
              let content = json["content"] as? String else {
            throw YouVersionAPIError.invalidDownload
        }

        return content
    }

    // MARK: - utility structs

    private struct BibleVersionBook: Codable {
        let id: String?
        let title: String?
        let abbreviation: String?
        let canon: String?
        let chapters: [String]?  // USFM codes
    }

    private struct BibleVersionIndexVerses: Codable {
        let id: String?
        let title: String?
    }

    private struct BibleVersionIndexChapter: Codable {
        let id: String?
        let title: String?
        let verses: [BibleVersionIndexVerses]?
    }

    private struct BibleVersionIndexBook: Codable {
        let id: String?
        let title: String?
        let full_title: String?
        let abbreviation: String?
        let canon: String?
        let chapters: [BibleVersionIndexChapter]?
    }

    private struct BibleVersionIndex: Codable {
        let text_direction: String?
        let books: [BibleVersionIndexBook]?
    }
}
