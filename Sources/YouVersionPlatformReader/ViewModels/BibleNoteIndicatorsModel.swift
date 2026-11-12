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
            bibleID: reference.versionId, passageID: reference.chapterPassageId,
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
        let signedInAccount = Account.signedIn
        if !canReadNotes || signedInAccount.userID == nil || snapshot?.account != signedInAccount {
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
        let requestAccount = Account.signedIn
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
                guard !Task.isCancelled && loadingRequestID == requestID else {
                    return
                }
                notes += result.notes
                token = result.nextPageToken
                if let token, !visitedTokens.insert(token).inserted {
                    throw URLError(.badServerResponse)
                }
            } while token != nil
            var seenIDs: Set<String> = []
            let cachedNotes: [(note: YouVersionNote, references: [BibleReference])] = notes.filter { seenIDs.insert($0.id).inserted }.compactMap { note in
                guard note.passage?.bibleID == reference.versionId,
                      let references = note.passage?.references else {
                    return nil
                }
                let chapterReferences = references.filter { $0.bookId == reference.bookId && $0.chapter == reference.chapter }
                return chapterReferences.isEmpty ? nil : (note: note, references: chapterReferences)
            }
            snapshot = Snapshot(chapter: chapter, account: requestAccount, notes: cachedNotes)
        } catch {
            guard !Task.isCancelled && loadingRequestID == requestID else {
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
        snapshot?.notes.contains { $0.references.contains { $0.overlaps(with: reference) } } ?? false
    }

    /// All notes whose exact attachment overlaps this rendered verse or verse bridge.
    func notes(for reference: BibleReference) -> [YouVersionNote] {
        snapshot?.notes.compactMap { cached in
            cached.references.contains { $0.overlaps(with: reference) } ? cached.note : nil
        } ?? []
    }

    private struct Snapshot {
        let chapter: BibleReference
        let account: Account
        let notes: [(note: YouVersionNote, references: [BibleReference])]
    }

    private struct Account: Equatable {
        let userID: String?
        let appKey: String?
        let apiHost: String

        static var signedIn: Self {
            Self(
                userID: YouVersionAPI.Users.currentUserId,
                appKey: YouVersionPlatformConfiguration.appKey,
                apiHost: YouVersionPlatformConfiguration.apiHost
            )
        }
    }

}
