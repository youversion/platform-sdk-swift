import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension YouVersionAPI {
    /// Authenticated beta Notes endpoints. Sign in with `read_notes` and/or `write_notes` permissions.
    struct Notes {
        /// Returns one page of the signed-in user's notes, newest first. Requires `read_notes`.
        ///
        /// Set `passageID` to a verse (`JHN.3.16`), a verse range within one chapter (`JHN.3.16-18`),
        /// same-chapter selections joined with `+` (`JHN.3.16+JHN.3.18`), or a chapter (`JHN.3`)
        /// to return notes whose attached passage overlaps it, regardless of Bible version.
        /// Nil returns notes without a passage filter. Cross-chapter or malformed selectors
        /// are rejected by the server with HTTP 400.
        /// Set `bibleID` to restrict results to that Bible translation. Notes without a passage
        /// do not match. When both filters are set, a note must match both.
        ///
        /// Page size must be between 1 and 99; nil uses the server default of 25. Even an empty or
        /// short page may have a next page token. Continue until the token is nil, passing it unchanged
        /// with the same `passageID` and `bibleID`; `pageSize` may vary. A terminal HTTP 204 returns an empty page.
        /// Throws `YouVersionAPIRequestError` for an invalid page size, `YouVersionAPIError` for
        /// authentication or HTTP failures, and decoding or transport errors when applicable.
        public static func notes(
            bibleID: Int? = nil,
            passageID: String? = nil,
            pageSize: Int? = nil,
            pageToken: String? = nil,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionNoteCollection {
            guard pageSize.map({ (1...99).contains($0) }) ?? true else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            let response = try await responseData(
                url: URLBuilder.notesURL(bibleID: bibleID, passageID: passageID, pageSize: pageSize, pageToken: pageToken),
                allowsNoContent: true,
                accessToken: providedToken,
                session: session
            )
            if response.statusCode == 204 {
                return YouVersionNoteCollection(notes: [], nextPageToken: nil)
            }
            return try JSONDecoder().decode(YouVersionNoteCollection.self, from: response.data)
        }

        /// Returns a note owned by the signed-in user. Requires `read_notes`.
        /// Throws for an empty ID, missing authentication, HTTP failure, or malformed response.
        public static func note(
            id: String,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionNote {
            guard !id.isEmpty else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            let response = try await responseData(
                url: URLBuilder.noteURL(id: id), accessToken: providedToken, session: session
            )
            return try JSONDecoder().decode(YouVersionNote.self, from: response.data)
        }

        /// Creates a note and returns its server representation. Requires `write_notes`.
        /// Reuse the same request value for retries so its `requestID` remains unchanged.
        /// Throws for empty content, missing authentication, HTTP failure, or malformed response.
        public static func createNote(
            _ note: YouVersionNoteCreateRequest,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionNote {
            guard !note.content.isEmpty else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            let response = try await responseData(
                url: URLBuilder.notesURL(bibleID: nil, passageID: nil, pageSize: nil, pageToken: nil),
                method: "POST",
                body: try JSONEncoder().encode(note),
                successStatus: 201,
                accessToken: providedToken,
                session: session
            )
            return try JSONDecoder().decode(YouVersionNote.self, from: response.data)
        }

        /// Partially updates a note and returns its server representation. Requires `write_notes`.
        /// Omitted fields retain their values; `.clear` sends explicit null for nullable fields.
        /// Throws for an empty ID, empty update or content, missing authentication, HTTP failure,
        /// or malformed response. Other value constraints are validated by the server.
        public static func updateNote(
            id: String,
            update: YouVersionNoteUpdate,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> YouVersionNote {
            guard !id.isEmpty && !update.isEmpty && update.content?.isEmpty != true else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            let response = try await responseData(
                url: URLBuilder.noteURL(id: id),
                method: "PATCH",
                body: try JSONEncoder().encode(update),
                accessToken: providedToken,
                session: session
            )
            return try JSONDecoder().decode(YouVersionNote.self, from: response.data)
        }

        /// Deletes a note owned by the signed-in user. Requires `write_notes`.
        /// Returns true on HTTP 204; throws for an empty ID, missing authentication, or HTTP failure.
        public static func deleteNote(
            id: String,
            accessToken providedToken: String? = nil,
            session: URLSession = .shared
        ) async throws -> Bool {
            guard !id.isEmpty else {
                throw YouVersionAPIRequestError(code: .invalidParameter)
            }
            _ = try await responseData(
                url: URLBuilder.noteURL(id: id), method: "DELETE", successStatus: 204,
                accessToken: providedToken, session: session
            )
            return true
        }

        private static func responseData(
            url: URL?,
            method: String = "GET",
            body: Data? = nil,
            successStatus: Int = 200,
            allowsNoContent: Bool = false,
            accessToken providedToken: String?,
            session: URLSession
        ) async throws -> (data: Data, statusCode: Int) {
            guard let accessToken = await YouVersionAPI.accessToken(providedToken: providedToken, session: session) else {
                throw YouVersionAPIError.missingAuthentication
            }
            guard let url else {
                throw URLError(.badURL)
            }
            var request = YouVersionAPI.urlRequest(
                with: url, accessToken: accessToken, session: session, cachePolicy: .reloadIgnoringLocalCacheData
            )
            request.httpMethod = method
            request.httpBody = body
            if body != nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw YouVersionAPIError.invalidResponse
            }
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw YouVersionAPIError.notPermitted
            }
            if allowsNoContent && httpResponse.statusCode == 204 {
                return (data, httpResponse.statusCode)
            }
            guard httpResponse.statusCode == successStatus else {
                throw YouVersionAPIError.cannotDownload
            }
            return (data, httpResponse.statusCode)
        }
    }
}
