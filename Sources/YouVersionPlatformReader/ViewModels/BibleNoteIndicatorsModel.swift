import Foundation
import Observation
import YouVersionPlatformCore

/// Chapter-scoped Notes loading for the opt-in Bible text integration.
@MainActor
@Observable
final class BibleNoteIndicatorsModel {
    private var snapshot: Snapshot?
    private var requestID = UUID()
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
            references: [reference.chapterReference],
            pageSize: 99, pageToken: pageToken
        )
    }

    /// Drops data and invalidates in-flight results when the account changes.
    func clear() {
        requestID = UUID()
        snapshot = nil
        loadFailed = false
    }

    /// Invalidates pending requests, retaining a snapshot only while its account still has read access.
    func authorizationDidChange() {
        let signedInAccount = BibleReaderAccount.current
        if !canReadNotes || signedInAccount?.userID == nil || snapshot?.account != signedInAccount {
            clear()
        } else {
            requestID = UUID()
            loadFailed = false
        }
    }

    /// Whether the caller may start loading Notes for the signed-in user.
    var canReadNotes: Bool { hasAccess() }

    /// Fetches every page and publishes one complete snapshot. The caller checks `canReadNotes` first.
    /// A same-account, same-chapter refresh retains its snapshot until success, including on transient failure.
    func load(_ reference: BibleReference) async {
        let chapter = reference.chapterReference
        let requestAccount = BibleReaderAccount.current
        if let snapshot, snapshot.chapter != chapter || snapshot.account != requestAccount {
            self.snapshot = nil
        }
        requestID = UUID()
        loadFailed = false
        let loadingRequestID = requestID
        do {
            var notes: [YouVersionNote] = []
            var token: String?
            var visitedTokens: Set<String> = []
            repeat {
                let result = try await notesPage(chapter, token)
                guard !Task.isCancelled && loadingRequestID == requestID && BibleReaderAccount.current == requestAccount else {
                    return
                }
                notes += result.notes
                token = result.nextPageToken
                if let token, !visitedTokens.insert(token).inserted {
                    throw URLError(.badServerResponse)
                }
            } while token != nil
            var seenIDs: Set<String> = []
            let cachedNotes = notes.filter { note in
                guard seenIDs.insert(note.id).inserted, let references = note.references else {
                    return false
                }
                return references.contains { $0.versionId == chapter.versionId && $0.bookId == chapter.bookId && $0.chapter == chapter.chapter }
            }
            snapshot = Snapshot(chapter: chapter, account: requestAccount, notes: cachedNotes)
        } catch {
            guard !Task.isCancelled && loadingRequestID == requestID && BibleReaderAccount.current == requestAccount else {
                return
            }
            switch error {
            case YouVersionAPIError.notPermitted, YouVersionAPIError.missingAuthentication:
                clear()
            default:
                break
            }
            loadFailed = true
            YouVersionPlatformLogger.error("Could not load Notes indicators: \(error)", category: "BibleText")
        }
    }

    /// Whether a verse needs an indicator, without allocating a matching-notes array during text construction.
    func hasNotes(for reference: BibleReference) -> Bool {
        snapshot?.notes.contains { $0.references?.contains { $0.overlaps(with: reference) } ?? false } ?? false
    }

    /// All notes whose exact attachment overlaps this rendered verse or verse bridge.
    func notes(for reference: BibleReference) -> [YouVersionNote] {
        snapshot?.notes.filter { $0.references?.contains { $0.overlaps(with: reference) } ?? false } ?? []
    }

    private struct Snapshot {
        let chapter: BibleReference
        let account: BibleReaderAccount?
        let notes: [YouVersionNote]
    }

}
