import Foundation
import Observation
import YouVersionPlatformCore

/// Chapter-scoped Notes loading for the opt-in Bible text integration.
@MainActor
@Observable
final class BibleNoteIndicatorsModel {
    private var cachedNotes: [(note: YouVersionNote, references: [BibleReference])] = []
    private var requestID = UUID()
    private var loadedChapter: BibleReference?
    private let hasAccess: @MainActor () -> Bool
    private let notesPage: @MainActor (BibleReference, String?) async throws -> YouVersionNoteCollection
    private(set) var loadFailed = false

    init(
        hasAccess: @escaping @MainActor () -> Bool = BibleNoteIndicatorsModel.hasReadAccess,
        notesPage: @escaping @MainActor (BibleReference, String?) async throws -> YouVersionNoteCollection = BibleNoteIndicatorsModel.defaultNotesPage
    ) {
        self.hasAccess = hasAccess
        self.notesPage = notesPage
    }

    // A function is needed here as the initializer’s authorization callback.
    // swiftlint:disable:next var_over_func
    private static func hasReadAccess() -> Bool {
        YouVersionAPI.isSignedIn && YouVersionAPI.hasPermission(YouVersionAPI.Users.readNotesPermission)
    }

    private static func defaultNotesPage(_ reference: BibleReference, _ pageToken: String?) async throws -> YouVersionNoteCollection {
        try await YouVersionAPI.Notes.notes(
            bibleID: reference.versionId, passageID: reference.chapterPassageId,
            pageSize: 99, pageToken: pageToken
        )
    }

    /// Drops data and invalidates in-flight results when the account changes.
    func clear() {
        requestID = UUID()
        cachedNotes = []
        loadedChapter = nil
        loadFailed = false
    }

    /// Loads every page atomically, retaining the current chapter's indicators during a refresh.
    /// Account or chapter changes clear cached notes; failed refreshes never replace them with partial results.
    func load(_ reference: BibleReference) async {
        let canRead = hasAccess()
        if !canRead || loadedChapter != reference.chapterReference {
            clear()
        } else {
            requestID = UUID()
            loadFailed = false
        }
        let currentRequest = requestID
        guard canRead else {
            return
        }
        do {
            var notes: [YouVersionNote] = []
            var token: String?
            var visitedTokens: Set<String> = []
            repeat {
                let result = try await notesPage(reference.chapterReference, token)
                guard !Task.isCancelled && currentRequest == requestID else {
                    return
                }
                notes += result.notes
                token = result.nextPageToken
                if let token, !visitedTokens.insert(token).inserted {
                    throw URLError(.badServerResponse)
                }
            } while token != nil
            var seenIDs: Set<String> = []
            cachedNotes = notes.filter { seenIDs.insert($0.id).inserted }.compactMap { note in
                guard note.passage?.bibleID == reference.versionId,
                      let references = note.passage?.references else {
                    return nil
                }
                let chapterReferences = references.filter { $0.bookId == reference.bookId && $0.chapter == reference.chapter }
                return chapterReferences.isEmpty ? nil : (note: note, references: chapterReferences)
            }
            loadedChapter = reference.chapterReference
        } catch {
            guard !Task.isCancelled && currentRequest == requestID else {
                return
            }
            loadFailed = true
            YouVersionPlatformLogger.error("Could not load Notes indicators: \(error)", category: "BibleText")
        }
    }

    /// Whether a verse needs an indicator, without allocating a matching-notes array during text construction.
    func hasNotes(for reference: BibleReference) -> Bool {
        cachedNotes.contains { $0.references.contains { $0.overlaps(with: reference) } }
    }

    /// All notes whose exact attachment overlaps this rendered verse or verse bridge.
    func notes(for reference: BibleReference) -> [YouVersionNote] {
        cachedNotes.compactMap { cached in
            cached.references.contains { $0.overlaps(with: reference) } ? cached.note : nil
        }
    }
}
