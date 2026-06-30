import Observation
import YouVersionPlatformCore

/// Requests the reference a ``BibleReaderView`` should show next, from elsewhere in
/// the app.
@MainActor
@Observable
public final class BibleReaderNavigation {
    /// A pending reference for the reader: which reference to move to, and whether to
    /// show its full chapter or only its verse range.
    public struct PendingReference: Equatable, Sendable {
        public let reference: BibleReference
        public let showsFullChapter: Bool
    }

    /// The reference the reader should move to next, or nil when there is nothing
    /// pending.
    public private(set) var pendingReference: PendingReference?

    public init() {}

    /// Requests that the connected reader move to `reference`. Safe to call from
    /// any view that shares this object — the reader need not be on screen yet; it
    /// picks up the pending reference when it appears.
    ///
    /// - Parameters:
    ///   - reference: The reference to move to.
    ///   - showsFullChapter: When `true`, show the full chapter scrolled to the
    ///     reference's verse. When `false` (the default), show only the verse range.
    public func request(_ reference: BibleReference, showsFullChapter: Bool = false) {
        pendingReference = PendingReference(reference: reference, showsFullChapter: showsFullChapter)
    }

    /// The reader calls this once it has begun moving to the reference,
    /// so the same request doesn't fire again.
    func consumePendingReference() {
        pendingReference = nil
    }
}
