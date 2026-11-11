import Foundation
import Testing
@testable import YouVersionPlatformCore
@testable import YouVersionPlatformReader

@MainActor
struct BibleNoteIndicatorsTests {
    private let chapter = BibleReference(versionId: 3034, bookId: "GEN", chapter: 1)

    private func collection(_ notes: [[String: Any]], next: String? = nil) throws -> YouVersionNoteCollection {
        var json: [String: Any] = ["data": notes]
        if let next { json["next_page_token"] = next }
        return try JSONDecoder().decode(YouVersionNoteCollection.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func note(_ id: String, passage: String, bibleID: Int = 3034) -> [String: Any] {
        ["id": id, "content": "Reflection", "status": "private", "passage": ["bible_id": bibleID, "passage_id": passage]]
    }

    private func verse(_ number: Int, chapter: Int = 1, versionID: Int = 3034) -> BibleReference {
        BibleReference(versionId: versionID, bookId: "GEN", chapter: chapter, verse: number)
    }

    @Test
    func fetchesAllPagesIncludingEmptyPagesAndPreservesExactGapsAndBibleVersion() async throws {
        let empty = try collection([], next: "next+opaque")
        let page = try collection([
            note("gapped", passage: "GEN.1.1+GEN.1.3+GEN.1.5"),
            note("range", passage: "GEN.1.3-4"),
            note("foreign", passage: "GEN.1.3", bibleID: 111),
            note("other-chapter", passage: "GEN.2.3"),
            note("invalid", passage: "GEN.1.1+bad")
        ], next: "last")
        let final = try collection([note("gapped", passage: "GEN.1.1+GEN.1.3+GEN.1.5")])
        var requested: [String?] = []
        let model = BibleNoteIndicatorsModel(hasAccess: { true }) { reference, token in
            #expect(reference == chapter)
            requested.append(token)
            return token == nil ? empty : token == "next+opaque" ? page : final
        }
        await model.load(verse(3))
        #expect(requested == [nil, "next+opaque", "last"])
        #expect(model.notes(for: verse(1)).map(\.id) == ["gapped"])
        #expect(model.notes(for: verse(2)).isEmpty)
        #expect(model.notes(for: verse(3)).map(\.id) == ["gapped", "range"])
        #expect(model.notes(for: verse(4)).map(\.id) == ["range"])
        #expect(model.notes(for: verse(5)).map(\.id) == ["gapped"])
        #expect(model.notes(for: verse(3, versionID: 111)).isEmpty)
        #expect(!model.loadFailed)
    }

    @Test
    func signedOutOrMissingPermissionDoesNotFetchOrShowIndicators() async throws {
        let access = AccessState()
        var requests = 0
        let page = try collection([note("one", passage: "GEN.1.1")])
        let model = BibleNoteIndicatorsModel(hasAccess: { access.isAllowed }) { _, _ in
            requests += 1
            return page
        }
        await model.load(chapter)
        #expect(!model.notes(for: verse(1)).isEmpty)
        access.isAllowed = false
        await model.load(chapter)
        #expect(requests == 1)
        #expect(model.notes(for: verse(1)).isEmpty)
    }

    @Test
    func failureOnALaterPageDoesNotPublishPartialResults() async throws {
        let first = try collection([note("one", passage: "GEN.1.1")], next: "next")
        let model = BibleNoteIndicatorsModel(hasAccess: { true }) { _, token in
            if token != nil { throw URLError(.cannotConnectToHost) }
            return first
        }
        await model.load(chapter)
        #expect(model.loadFailed)
        #expect(model.notes(for: verse(1)).isEmpty)
    }

    @Test
    func refreshRetainsCachedNotesUntilCompleteAndFailureDoesNotReplaceThem() async throws {
        let original = try collection([note("old", passage: "GEN.1.3")])
        let partial = try collection([note("partial", passage: "GEN.1.4")], next: "next")
        let refresh = RefreshState()
        weak var observedModel: BibleNoteIndicatorsModel?
        let model = BibleNoteIndicatorsModel(hasAccess: { true }) { _, token in
            guard refresh.isRefreshing else { return original }
            #expect(observedModel?.hasNotes(for: verse(3)) == !refresh.isSwitchingChapters)
            if token != nil { throw URLError(.cannotConnectToHost) }
            return partial
        }
        observedModel = model
        await model.load(chapter)
        refresh.isRefreshing = true
        await model.load(chapter)
        #expect(model.loadFailed)
        #expect(model.notes(for: verse(3)).map(\.id) == ["old"])
        #expect(!model.hasNotes(for: verse(4)))
        refresh.isSwitchingChapters = true
        await model.load(verse(1, chapter: 2))
        #expect(!model.hasNotes(for: verse(3)))
        model.clear()
        #expect(!model.loadFailed)
    }

    @Test
    func repeatedContinuationTokenStopsInsteadOfLooping() async throws {
        let page = try collection([], next: "repeat")
        var requests = 0
        let model = BibleNoteIndicatorsModel(hasAccess: { true }) { _, _ in
            requests += 1
            return page
        }
        await model.load(chapter)
        #expect(requests == 2)
        #expect(model.loadFailed)
    }

    @Test(arguments: [false, true])
    func staleResultsCannotRepopulateADifferentChapterOrSignedOutAccount(signOut: Bool) async throws {
        let old = try collection([note("old", passage: "GEN.1.1")])
        let new = try collection([note("new", passage: "GEN.2.1")])
        var resume: CheckedContinuation<YouVersionNoteCollection, Never>?
        let model = BibleNoteIndicatorsModel(hasAccess: { true }) { reference, _ in
            if reference.chapter == 1 {
                return await withCheckedContinuation { resume = $0 }
            }
            return new
        }
        let oldTask = Task { await model.load(chapter) }
        for _ in 0..<100 where resume == nil { await Task.yield() }
        let continuation = try #require(resume)
        if signOut {
            model.clear()
        } else {
            await model.load(verse(1, chapter: 2))
        }
        continuation.resume(returning: old)
        await oldTask.value
        #expect(model.notes(for: verse(1)).isEmpty)
        #expect(model.notes(for: verse(1, chapter: 2)).map(\.id) == (signOut ? [] : ["new"]))
    }


}

@MainActor
private final class AccessState {
    var isAllowed = true
}

@MainActor
private final class RefreshState {
    var isRefreshing = false
    var isSwitchingChapters = false
}
