import Observation
import YouVersionPlatformCore

@MainActor
@Observable
public final class BibleReaderNavigation {
    /// A request for the reader: which reference to move to, and whether to
    /// show its full chapter or only its verse range.
    public struct Request: Equatable, Sendable {
        public let reference: BibleReference
        public let showsFullChapter: Bool
    }

    /// The request the reader should act on next.
    public private(set) var pendingRequest: Request?

    public init() {}

    /// Requests that the connected reader move to `reference`. Safe to call from
    /// any view that shares this object — the reader need not be on screen yet; it
    /// picks up the pending reference when it appears.
    public func request(_ reference: BibleReference, showsFullChapter: Bool = false) {
        pendingRequest = Request(reference: reference, showsFullChapter: showsFullChapter)
    }

    /// Called by the reader once it has begun acting on the request.
    func consumePendingRequest() {
        pendingRequest = nil
    }
}
