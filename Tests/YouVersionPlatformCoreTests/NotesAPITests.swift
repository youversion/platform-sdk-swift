import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import YouVersionPlatformCore

struct NotesAPITests {
    private let noteJSON = """
    {"id":"40638","title":"Reflection","content":"Trust the process.","color":"44aa44",
    "passage":{"bible_id":3034,"passage_id":"JHN.3.16-18"},"language_tag":"en-US","tags":["faith"],
    "status":"private","created_dt":"2026-10-23T17:00:00Z","updated_dt":null}
    """

    @Test
    func collectionPreservesPaginationAndDecodesMetadata() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let pageToken = "a+b/c==&?% fragment"
        let json = Data("{\"data\":[\(noteJSON)],\"next_page_token\":\"next+opaque/=\"}".utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(request.httpMethod == "GET")
            #expect(components.path == "/v1-beta/notes")
            #expect(components.queryItems == [
                URLQueryItem(name: "page_size", value: "99"), URLQueryItem(name: "page_token", value: pageToken)
            ])
            #expect(components.percentEncodedQuery?.contains("a%2Bb") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer notes-tests")
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Notes.notes(
            pageSize: 99, pageToken: pageToken, accessToken: "notes-tests", session: session
        )
        #expect(page.nextPageToken == "next+opaque/=")
        let note = try #require(page.notes.first)
        #expect(note.id == "40638")
        #expect(note.title == "Reflection")
        #expect(note.content == "Trust the process.")
        #expect(note.color == "44aa44")
        #expect(note.passage == YouVersionNote.Passage(bibleID: 3034, passageID: "JHN.3.16-18"))
        #expect(note.languageTag == "en-US")
        #expect(note.tags == ["faith"])
        #expect(note.status == .private)
        #expect(note.createdTime == "2026-10-23T17:00:00Z")
        #expect(note.updatedTime == nil)
    }

    @Test(arguments: [200, 204])
    func emptyPagesAndOmittedPagination(status: Int) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.url?.query == nil)
            let data = status == 204 ? Data() : Data(#"{"data":[],"next_page_token":null}"#.utf8)
            return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Notes.notes(accessToken: "notes-tests", session: session)
        #expect(page.notes.isEmpty)
        #expect(page.nextPageToken == nil)
    }

    @Test(arguments: ["JHN.3.16", "JHN.3.16-18", "JHN.3"])
    func passageFilterAcceptsVerseRangeAndChapter(passageID: String) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = Data("{\"data\":[\(noteJSON)]}".utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.queryItems == [URLQueryItem(name: "passage_id", value: passageID)])
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Notes.notes(passageID: passageID, accessToken: "notes-tests", session: session)
        #expect(page.notes.first?.passage?.bibleID == 3034)
    }

    @Test(arguments: [false, true])
    func filteredEmptyAndShortPagesPreserveContinuation(hasNote: Bool) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let passageID = "JHN.3"
        let nextPageToken = "next+opaque/=&?%"
        let data = hasNote ? noteJSON : ""
        let pageJSON = Data("{\"data\":[\(data)],\"next_page_token\":\"\(nextPageToken)\"}".utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let items = components.queryItems ?? []
            #expect(items.first { $0.name == "passage_id" }?.value == passageID)
            #expect(items.first { $0.name == "bible_id" }?.value == "3034")
            if let token = items.first(where: { $0.name == "page_token" })?.value {
                #expect(token == nextPageToken)
                #expect(items.first { $0.name == "page_size" }?.value == "1")
                return (Data(), HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!)
            }
            #expect(items.first { $0.name == "page_size" }?.value == "25")
            return (pageJSON, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let first = try await YouVersionAPI.Notes.notes(
            bibleID: 3034, passageID: passageID, pageSize: 25, accessToken: "notes-tests", session: session
        )
        #expect(first.notes.count == (hasNote ? 1 : 0))
        let continuation = try #require(first.nextPageToken)
        #expect(continuation == nextPageToken)
        let last = try await YouVersionAPI.Notes.notes(
            bibleID: 3034, passageID: passageID, pageSize: 1, pageToken: continuation, accessToken: "notes-tests", session: session
        )
        #expect(last.notes.isEmpty)
        #expect(last.nextPageToken == nil)
    }

    @Test(arguments: [false, true])
    func bibleFilterWorksAloneOrWithPassage(hasPassage: Bool) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let passageID = hasPassage ? "JHN.3" : nil
        let json = Data("{\"data\":[\(noteJSON)]}".utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let items = components.queryItems ?? []
            #expect(items.count == (hasPassage ? 2 : 1))
            #expect(items.first { $0.name == "bible_id" }?.value == "3034")
            #expect(items.first { $0.name == "passage_id" }?.value == passageID)
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Notes.notes(
            bibleID: 3034, passageID: passageID, accessToken: "notes-tests", session: session
        )
        #expect(page.notes.first?.passage?.bibleID == 3034)
    }

    @Test
    func bibleFilterWithNoMatchesReturnsEmptyPage() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.queryItems == [URLQueryItem(name: "bible_id", value: "999999")])
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!)
        }
        let page = try await YouVersionAPI.Notes.notes(bibleID: 999999, accessToken: "notes-tests", session: session)
        #expect(page.notes.isEmpty)
        #expect(page.nextPageToken == nil)
    }

    @Test(arguments: [0, -1])
    func nonpositiveBibleIDsPropagateServerRejections(bibleID: Int) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.queryItems == [URLQueryItem(name: "bible_id", value: String(bibleID))])
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        }
        await #expect {
            try await YouVersionAPI.Notes.notes(bibleID: bibleID, accessToken: "notes-tests", session: session)
        } throws: { ($0 as? YouVersionAPIError) == .cannotDownload }
    }

    @Test(arguments: ["", "JHN.3.16,GEN.1.1", "JHN.3&passage_id=GEN.1+%#"])
    func invalidPassageSelectorsAreEncodedAndServerRejectionsPropagate(passageID: String) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            #expect(components.queryItems == [URLQueryItem(name: "passage_id", value: passageID)])
            #expect(components.fragment == nil)
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        }
        await #expect {
            try await YouVersionAPI.Notes.notes(passageID: passageID, accessToken: "notes-tests", session: session)
        } throws: { ($0 as? YouVersionAPIError) == .cannotDownload }
    }

    @Test
    func nonconsecutivePassageSurvivesCreateReadUpdateAndList() async throws {
        let references = [1, 3, 5].map { BibleReference(versionId: 3034, bookId: "GEN", chapter: 1, verse: $0) }
        let passage = try #require(YouVersionNote.Passage(references: references))
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = Data(noteJSON.replacingOccurrences(of: "JHN.3.16-18", with: passage.passageID).utf8)
        HTTPMocking.setHandler(token: token) { request in
            if request.httpMethod == "POST" || request.httpMethod == "PATCH" {
                let body = try #require(request.bodyStreamAsJSON() as? [String: Any])
                let attachment = try #require(body["passage"] as? [String: Any])
                #expect(attachment["bible_id"] as? Int == 3034)
                #expect(attachment["passage_id"] as? String == "GEN.1.1+GEN.1.3+GEN.1.5")
            }
            let isList = request.httpMethod == "GET" && request.url?.path == "/v1-beta/notes"
            if isList {
                let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
                #expect(components.queryItems == [URLQueryItem(name: "passage_id", value: passage.passageID)])
                #expect(components.percentEncodedQuery == "passage_id=GEN.1.1%2BGEN.1.3%2BGEN.1.5")
            }
            let response = isList ? Data("{\"data\":[\(String(decoding: json, as: UTF8.self))]}".utf8) : json
            return (response, HTTPURLResponse(url: request.url!, statusCode: request.httpMethod == "POST" ? 201 : 200, httpVersion: nil, headerFields: nil)!)
        }
        let created = try await YouVersionAPI.Notes.createNote(
            YouVersionNoteCreateRequest(content: "Reflection", status: .private, passage: passage),
            accessToken: "notes-tests", session: session
        )
        let read = try await YouVersionAPI.Notes.note(id: "40638", accessToken: "notes-tests", session: session)
        let updated = try await YouVersionAPI.Notes.updateNote(
            id: "40638", update: YouVersionNoteUpdate(passage: .value(passage)), accessToken: "notes-tests", session: session
        )
        let page = try await YouVersionAPI.Notes.notes(passageID: passage.passageID, accessToken: "notes-tests", session: session)
        for note in [created, read, updated] + page.notes {
            #expect(note.passage?.references == references)
        }
    }

    @Test
    func creationEncodesContractAndRetainsIdempotencyOnRetry() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let requestID = UUID()
        let json = Data(noteJSON.utf8)
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/v1-beta/notes")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer notes-tests")
            let body = try #require(request.bodyStreamAsJSON() as? [String: Any])
            #expect(body["request_id"] as? String == requestID.uuidString)
            #expect(body["content"] as? String == "New note")
            #expect(body["status"] as? String == "public")
            #expect(body["title"] as? String == "Title")
            #expect(body["color"] as? String == "44aa44")
            #expect(body["language_tag"] as? String == "en-US")
            #expect(body["tags"] as? [String] == ["faith"])
            let passage = try #require(body["passage"] as? [String: Any])
            #expect(passage["bible_id"] as? Int == 3034)
            #expect(passage["passage_id"] as? String == "JHN.3.16")
            #expect(body["id"] == nil)
            return (json, HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!)
        }
        let request = YouVersionNoteCreateRequest(
            content: "New note", status: .public, requestID: requestID, title: "Title", color: "44aa44",
            passage: YouVersionNote.Passage(bibleID: 3034, passageID: "JHN.3.16"), languageTag: "en-US", tags: ["faith"]
        )
        let first = try await YouVersionAPI.Notes.createNote(request, accessToken: "notes-tests", session: session)
        let retry = try await YouVersionAPI.Notes.createNote(request, accessToken: "notes-tests", session: session)
        #expect(first == retry)
    }

    @Test(arguments: ["", " \n\t "])
    func creationAllowsSavingAPassageWithoutText(content: String) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let passage = YouVersionNote.Passage(bibleID: 3034, passageID: "JHN.3.16")
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.httpMethod == "POST")
            let body = try #require(request.bodyStreamAsJSON() as? [String: Any])
            #expect(body["content"] as? String == content)
            #expect((body["passage"] as? [String: Any])?["passage_id"] as? String == passage.passageID)
            var response = body
            response["id"] = "saved-verse"
            return (
                try JSONSerialization.data(withJSONObject: response),
                HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            )
        }
        let note = try await YouVersionAPI.Notes.createNote(
            YouVersionNoteCreateRequest(content: content, status: .private, passage: passage),
            accessToken: "notes-tests", session: session
        )
        #expect(note.content == content)
        #expect(note.passage == passage)
    }

    @Test
    func patchDistinguishesOmittedNullAndReplacementFields() async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = Data(noteJSON.utf8)
        HTTPMocking.setHandler(token: token) { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url?.path == "/v1-beta/notes/40638")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let body = try #require(request.bodyStreamAsJSON() as? [String: Any])
            #expect(body.count == 4)
            #expect(body["title"] is NSNull)
            #expect(body["passage"] is NSNull)
            #expect(body["content"] as? String == "Changed")
            #expect(body["tags"] as? [String] == [])
            #expect(body["status"] == nil)
            #expect(body["color"] == nil)
            #expect(body["language_tag"] == nil)
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        _ = try await YouVersionAPI.Notes.updateNote(
            id: "40638", update: YouVersionNoteUpdate(title: .clear, content: "Changed", passage: .clear, tags: .value([])),
            accessToken: "notes-tests", session: session
        )
    }

    @Test
    func allNullableUpdateFieldsCanBeCleared() throws {
        let update = YouVersionNoteUpdate(title: .clear, color: .clear, passage: .clear, languageTag: .clear, tags: .clear)
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(update)) as? [String: Any])
        #expect(object.count == 5)
        for field in ["title", "color", "passage", "language_tag", "tags"] {
            #expect(object[field] is NSNull)
        }
    }

    @Test
    func updateReplacementValuesUseWireKeys() throws {
        let update = YouVersionNoteUpdate(
            title: .value("New"), 
            color: .value("123abc"),
            passage: .value(YouVersionNote.Passage(bibleID: 1, passageID: "GEN.1.1")),
            languageTag: .value("es"), 
            tags: .value(["hope"]), 
            status: .public
        )
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(update)) as? [String: Any])
        #expect(object["title"] as? String == "New")
        #expect(object["color"] as? String == "123abc")
        #expect(object["language_tag"] as? String == "es")
        #expect(object["tags"] as? [String] == ["hope"])
        #expect(object["status"] as? String == "public")
        #expect((object["passage"] as? [String: Any])?["bible_id"] as? Int == 1)
    }

    @Test(arguments: ["id/with?query#fragment%2F +é", ".", ".."], [false, true])
    func resourceIDsRemainSingleSegments(id: String, isDelete: Bool) async throws {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        let json = Data(noteJSON.utf8)
        HTTPMocking.setHandler(token: token) { request in
            let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let prefix = "/v1-beta/notes/"
            #expect(components.percentEncodedPath.hasPrefix(prefix))
            let segment = String(components.percentEncodedPath.dropFirst(prefix.count))
            #expect(!segment.contains("/"))
            #expect(segment.removingPercentEncoding == id)
            #expect(components.query == nil)
            #expect(components.fragment == nil)
            #expect(request.httpMethod == (isDelete ? "DELETE" : "GET"))
            #expect(request.httpBody == nil)
            return (isDelete ? Data() : json,
                    HTTPURLResponse(url: request.url!, statusCode: isDelete ? 204 : 200, httpVersion: nil, headerFields: nil)!)
        }
        if isDelete {
            let deleted = try await YouVersionAPI.Notes.deleteNote(id: id, accessToken: "notes-tests", session: session)
            #expect(deleted)
        } else {
            let note = try await YouVersionAPI.Notes.note(id: id, accessToken: "notes-tests", session: session)
            #expect(note.id == "40638")
        }
    }

    @Test(arguments: [0, -1, 100, Int.max])
    func invalidPageSizesFailBeforeNetworking(pageSize: Int) async {
        await #expect {
            try await YouVersionAPI.Notes.notes(pageSize: pageSize)
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
    }

    @Test(arguments: 0..<6)
    func invalidInputsFailBeforeNetworking(operation: Int) async {
        await #expect {
            switch operation {
            case 0: _ = try await YouVersionAPI.Notes.note(id: "")
            case 1: _ = try await YouVersionAPI.Notes.deleteNote(id: "")
            case 2: _ = try await YouVersionAPI.Notes.updateNote(id: "", update: YouVersionNoteUpdate(content: "New"))
            case 3: _ = try await YouVersionAPI.Notes.updateNote(id: "40638", update: YouVersionNoteUpdate())
            case 4: _ = try await YouVersionAPI.Notes.updateNote(id: "40638", update: YouVersionNoteUpdate(content: ""))
            default: _ = try await YouVersionAPI.Notes.notes(pageSize: 100)
            }
        } throws: { ($0 as? YouVersionAPIRequestError)?.code == .invalidParameter }
    }

    @Test(arguments: [401, 403, 400, 404, 429, 500], 0..<5)
    func failuresPropagateForEveryEndpoint(status: Int, operation: Int) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        await #expect {
            try await performOperation(operation, session: session)
        } throws: { error in
            (error as? YouVersionAPIError) == (status == 401 || status == 403 ? .notPermitted : .cannotDownload)
        }
    }

    @Test(arguments: 0..<5)
    func transportFailuresPropagate(operation: Int) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { _ in throw URLError(.timedOut) }
        await #expect {
            try await performOperation(operation, session: session)
        } throws: { ($0 as? URLError)?.code == .timedOut }
    }

    @Test(arguments: 0..<4)
    func malformedResponsesThrow(operation: Int) async {
        let (session, token) = HTTPMocking.makeSession()
        defer { HTTPMocking.clear(token: token) }
        HTTPMocking.setHandler(token: token) { request in
            (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: operation == 2 ? 201 : 200,
                                            httpVersion: nil, headerFields: nil)!)
        }
        await #expect(throws: DecodingError.self) {
            try await performOperation(operation, session: session)
        }
    }

    @Test
    func optionalResponseFieldsMayBeOmittedAndUnknownStatusIsPreserved() throws {
        let data = Data(#"{"id":"1","content":"Note","status":"future-status"}"#.utf8)
        let note = try JSONDecoder().decode(YouVersionNote.self, from: data)
        #expect(note.title == nil)
        #expect(note.passage == nil)
        #expect(note.createdTime == nil)
        #expect(note.status.rawValue == "future-status")
        #expect(try JSONDecoder().decode(YouVersionNote.self, from: JSONEncoder().encode(note)) == note)
    }

    private func performOperation(_ operation: Int, session: URLSession) async throws {
        switch operation {
        case 0: _ = try await YouVersionAPI.Notes.notes(accessToken: "notes-tests", session: session)
        case 1: _ = try await YouVersionAPI.Notes.note(id: "40638", accessToken: "notes-tests", session: session)
        case 2:
            _ = try await YouVersionAPI.Notes.createNote(
                YouVersionNoteCreateRequest(content: "New", status: .private), accessToken: "notes-tests", session: session
            )
        case 3:
            _ = try await YouVersionAPI.Notes.updateNote(
                id: "40638", update: YouVersionNoteUpdate(content: "Changed"), accessToken: "notes-tests", session: session
            )
        default: _ = try await YouVersionAPI.Notes.deleteNote(id: "40638", accessToken: "notes-tests", session: session)
        }
    }
}
