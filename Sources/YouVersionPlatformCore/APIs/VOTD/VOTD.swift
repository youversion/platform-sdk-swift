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
        public static func verseOfTheDay(dayOfYear: Int, session: URLSession = .shared) async throws -> YouVersionVerseOfTheDay {
            let data = try await YouVersionAPI.commonFetch(
                url: URLBuilder.votdURL(dayOfYear: dayOfYear),
                session: session
            )
            guard let decodedResponse = try? JSONDecoder().decode(YouVersionVerseOfTheDay.self, from: data) else {
                throw URLError(.badServerResponse)
            }
            return decodedResponse
        }
    }
}
