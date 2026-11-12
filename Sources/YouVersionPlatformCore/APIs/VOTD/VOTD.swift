import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    enum VOTD {
        /// Retrieves the Verse of the Day from YouVersion for a specified Bible version.
        ///
        /// This function fetches the Verse of the Day using the provided `versionId` (defaulting to `1` for KJV if not specified),
        /// returning a ``YouVersionVerseOfTheDay`` model containing the verse text, reference, and related metadata.
        ///
        /// A valid `YouVersionPlatformConfiguration.appKey` must be set before calling this function.
        ///
        /// - Parameter versionId: The ID of the Bible version to use for retrieving the Verse of the Day. Defaults to `1` (KJV).
        /// - Returns: A ``YouVersionVerseOfTheDay`` containing the verse text, reference, and associated information.
        /// - Throws:
        ///   - `URLError.badURL` if the URL could not be constructed.
        ///   - `URLError.badServerResponse` if the server response could not be decoded.
        public static func verseOfTheDay(dayOfYear: Int, accessToken providedToken: String? = nil, session: URLSession = .shared) async throws -> YouVersionVerseOfTheDay {
            try await verseOfTheDay(dayOfYear: dayOfYear, languageRanges: [], accessToken: providedToken, session: session)
        }

        /// Retrieves the Verse of the Day for a day of the year, including a reference to its verse art.
        ///
        /// - Parameters:
        ///   - dayOfYear: The day of the year, from 1 through 366.
        ///   - languageRanges: Ordered basic language ranges that select the art's language.
        ///     Use `*` to select English; an empty array omits the parameter and `imageID` is `nil`.
        ///   - accessToken: An optional access token. Otherwise uses and refreshes the configured access token.
        ///   - session: The URL session used to perform the request.
        /// - Returns: The day's passage and day number, plus `imageID` when art exists for the requested ranges.
        /// - Throws:
        ///   - `URLError.badURL` if the URL could not be constructed.
        ///   - `URLError.badServerResponse` if the server response could not be decoded.
        ///   - `YouVersionAPIError.notPermitted` if the request is unauthorized or forbidden.
        ///   - `YouVersionAPIError.cannotDownload` if the server returns an unexpected status.
        public static func verseOfTheDay(
            dayOfYear: Int,
            languageRanges: [String],
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionVerseOfTheDay {
            guard let url = URLBuilder.votdURL(dayOfYear: dayOfYear, languageRanges: languageRanges) else {
                throw URLError(.badURL)
            }
            let data = try await YouVersionAPI.data(
                at: url,
                accessToken: await YouVersionAPI.accessToken(providedToken: providedToken, session: session),
                session: session
            )
            guard let decodedResponse = try? JSONDecoder().decode(YouVersionVerseOfTheDay.self, from: data) else {
                throw URLError(.badServerResponse)
            }
            return decodedResponse
        }

        /// Retrieves the Verse of the Day calendar for an entire year, with one item per day.
        ///
        /// - Parameters:
        ///   - languageRanges: Ordered basic language ranges that select the art's language.
        ///     Use `*` to select English; an empty array omits the parameter and every `imageID` is `nil`.
        ///   - accessToken: An optional access token. Otherwise uses and refreshes the configured access token.
        ///   - session: The URL session used to perform the request.
        /// - Returns: The year's verses, or an empty array when the server has no calendar data.
        /// - Throws:
        ///   - `URLError.badURL` if the URL could not be constructed.
        ///   - `URLError.badServerResponse` if the server response could not be decoded.
        ///   - `YouVersionAPIError.notPermitted` if the request is unauthorized or forbidden.
        ///   - `YouVersionAPIError.cannotDownload` if the server returns an unexpected status.
        public static func versesOfTheDay(
            languageRanges: [String] = [],
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> [YouVersionVerseOfTheDay] {
            guard let url = URLBuilder.votdCollectionURL(languageRanges: languageRanges) else {
                throw URLError(.badURL)
            }
            guard let data = try await YouVersionAPI.dataIfPresent(
                at: url,
                accessToken: await YouVersionAPI.accessToken(providedToken: providedToken, session: session),
                session: session
            ) else {
                return []
            }
            guard let decodedResponse = try? JSONDecoder().decode(VerseOfTheDayCollectionResponse.self, from: data) else {
                throw URLError(.badServerResponse)
            }
            return decodedResponse.data
        }
    }
}

private struct VerseOfTheDayCollectionResponse: Decodable {
    let data: [YouVersionVerseOfTheDay]
}
