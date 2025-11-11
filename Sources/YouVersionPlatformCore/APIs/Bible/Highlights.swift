import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    enum Highlights {

        // MARK: - Create (POST)

        /// Creates a new Bible highlight on YouVersion.
        ///
        /// This function creates a highlight for the specified passage using the provided parameters.
        ///
        /// - Parameters:
        ///   - bibleId: The ID of the Bible version.
        ///   - passageId: The passage identifier (e.g., "JHN.5.1").
        ///   - color: The hex color code for the highlight (e.g., "eeeeff").
        /// - Returns: A boolean indicating whether the highlight was successfully created.
        /// - Throws:
        ///   - `URLError.badURL` if the URL could not be constructed.
        ///   - `URLError.badServerResponse` if the server response was invalid.
        public static func createHighlight(
            bibleId: Int,
            passageId: String,
            color: String,
            session: URLSession = .shared
        ) async throws -> Bool {
            guard let url = URLBuilder.highlightsURL else {
                throw URLError(.badURL)
            }

            let requestBody = HighlightRequest(
                bibleId: bibleId,
                passageId: passageId,
                color: color.lowercased()
            )

            var request = YouVersionAPI.buildRequest(url: url, session: session)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            return httpResponse.statusCode >= 200 && httpResponse.statusCode < 300
        }

        // MARK: - Read (GET)

        /// Retrieves highlights for a specific Bible chapter from YouVersion.
        ///
        /// This function fetches highlights for the chapter identified by the provided `passageId` and `bibleId`
        /// for the authenticated user.
        ///
        /// A valid `YouVersionPlatformConfiguration.appKey` must be set before calling this function.
        ///
        /// - Parameters:
        ///   - bibleId: The ID of the Bible version to fetch highlights for.
        ///   - passageId: The passage identifier (e.g., "JHN.5").
        /// - Returns: An array of highlight data representing the user's highlights in the specified chapter.
        /// - Throws:
        ///   - `URLError.badURL` if the URL could not be constructed.
        ///   - `URLError.badServerResponse` if the server response could not be decoded.
        public static func getHighlights(
            bibleId: Int,
            passageId: String,
            session: URLSession = .shared
        ) async throws -> [HighlightResponse] {
            guard YouVersionAPI.isSignedIn else {
                return []
            }

            guard let url = URLBuilder.highlightsURL(bibleId: bibleId, passageId: passageId) else {
                throw URLError(.badURL)
            }

            let request = YouVersionAPI.buildRequest(
                url: url,
                session: session,
                cachePolicy: .reloadIgnoringLocalCacheData
            )
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 401 {
                print("getHighlights: error 401: unauthorized. Check your access token")
                return []
            }

            if httpResponse.statusCode == 204 {
                return []
            }

            guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                print("getHighlights: unexpected status code \(httpResponse.statusCode)")
                return []
            }

            guard let decodedResponse = try? JSONDecoder().decode(HighlightPaginatedResponse.self, from: data) else {
                throw URLError(.badServerResponse)
            }

            return decodedResponse.data
        }

        // MARK: - Update (PUT)

        /// Updates an existing Bible highlight on YouVersion.
        ///
        /// This function updates the color of an existing highlight for the specified passage.
        ///
        /// - Parameters:
        ///   - bibleId: The ID of the Bible version.
        ///   - passageId: The passage identifier (e.g., "JHN.5.1").
        ///   - color: The new hex color code for the highlight (e.g., "eeeeff").
        /// - Returns: A boolean indicating whether the highlight was successfully updated.
        /// - Throws:
        ///   - `URLError.badURL` if the URL could not be constructed.
        ///   - `URLError.badServerResponse` if the server response was invalid.
        public static func updateHighlight(
            bibleId: Int,
            passageId: String,
            color: String,
            session: URLSession = .shared
        ) async throws -> Bool {
            guard let url = URLBuilder.highlightsURL else {
                throw URLError(.badURL)
            }

            let requestBody = HighlightRequest(
                bibleId: bibleId,
                passageId: passageId,
                color: color.lowercased()
            )

            var request = YouVersionAPI.buildRequest(url: url, session: session)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            return httpResponse.statusCode >= 200 && httpResponse.statusCode < 300
        }

        // MARK: - Delete (DELETE)

        /// Deletes a Bible highlight from YouVersion.
        ///
        /// This function removes the highlight for the specified passage.
        /// A valid `YouVersionPlatformConfiguration.appKey` must be set before calling this function.
        ///
        /// - Parameters:
        ///   - bibleId: The ID of the Bible version.
        ///   - passageId: The passage identifier (e.g., "JHN.5.1").
        /// - Returns: A boolean indicating whether the highlight was successfully deleted.
        /// - Throws:
        ///   - `URLError.badURL` if the URL could not be constructed.
        ///   - `URLError.badServerResponse` if the server response was invalid.
        public static func deleteHighlight(
            bibleId: Int,
            passageId: String,
            session: URLSession = .shared
        ) async throws -> Bool {
            guard let url = URLBuilder.highlightsDeleteURL(bibleId: bibleId, passageId: passageId) else {
                throw URLError(.badURL)
            }
            var request = YouVersionAPI.buildRequest(url: url, session: session)
            request.httpMethod = "DELETE"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            return httpResponse.statusCode >= 200 && httpResponse.statusCode < 300
        }
    }
}

// MARK: - Request/Response Models

private struct HighlightRequest: Codable, CustomDebugStringConvertible {
    let bibleId: Int
    let passageId: String
    let color: String

    enum CodingKeys: String, CodingKey {
        case bibleId = "bible_id"
        case passageId = "passage_id"
        case color
    }
    
    var debugDescription: String {
        "HighlightRequest(bibleId: \(bibleId), passageId: \(passageId), color: \(color))"
    }
}

private struct HighlightDeleteRequest: Codable {
    let bibleId: Int
    let passageId: String

    enum CodingKeys: String, CodingKey {
        case bibleId = "bible_id"
        case passageId = "passage_id"
    }
}

public struct HighlightPaginatedResponse: Codable, Sendable {
    public let data: [HighlightResponse]
    public let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextPageToken = "next_page_token"
    }
}

public struct HighlightResponse: Codable, Sendable {
    public let id: String?
    public let bibleId: Int
    public let passageId: String
    public let color: String
    public let userId: String?
    public let createTime: String?
    public let updateTime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case bibleId = "bible_id"
        case passageId = "passage_id"
        case color
        case userId = "user_id"
        case createTime = "create_time"
        case updateTime = "update_time"
    }

    init(bibleId: Int, passageId: String, color: String) {
        self.id = nil
        self.bibleId = bibleId
        self.passageId = passageId
        self.color = color
        self.userId = nil
        self.createTime = nil
        self.updateTime = nil
    }
}
