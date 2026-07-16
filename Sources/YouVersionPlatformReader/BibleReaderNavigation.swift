import Observation
import YouVersionPlatformCore

@MainActor
@Observable
public final class BibleReaderNavigation {
    /// A request for the reader to act on.
    public struct Request: Equatable, Sendable {
        public let reference: BibleReference
        public let showsFullChapter: Bool
        public let scrollsToVerse: Bool
        public let shouldFocus: Bool
    }

    /// The request the reader should act on next.
    public private(set) var pendingRequest: Request?

    public init() {}

    /// Requests that the connected reader move to `reference`. Safe to call from
    /// any view that shares this object — the reader need not be on screen yet; it
    /// picks up the pending reference when it appears.
    public func request(_ reference: BibleReference, showsFullChapter: Bool = false) {
        pendingRequest = Request(
            reference: reference,
            showsFullChapter: showsFullChapter,
            scrollsToVerse: true,
            shouldFocus: false
        )
    }

    /// Requests that the connected reader focus `reference`'s verse, dimming the rest of
    /// the chapter around it.
    public func focusReference(_ reference: BibleReference, scrollsToVerse: Bool = true) {
        pendingRequest = Request(
            reference: reference,
            showsFullChapter: true,
            scrollsToVerse: scrollsToVerse,
            shouldFocus: true
        )
    }

    /// Called by the reader once it has begun acting on the request.
    func clearPendingRequest() {
        pendingRequest = nil
    }
}
