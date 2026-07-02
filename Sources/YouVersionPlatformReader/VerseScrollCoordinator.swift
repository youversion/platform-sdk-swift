import Observation
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// Scrolls the reader to a requested verse, working around three SwiftUI limitations:
/// - No "chapter finished laying out" signal, so readiness can't be observed directly.
/// - No synchronous text geometry (UIKit exposes it via TextKit's `selectionRects`), so
///   a verse's offset can't be measured before the first paint.
/// - `scrollPosition(id:)` doesn't fit: it needs `.scrollTargetLayout()` on a lazy
///   container, but our anchors live in the non-lazy `BibleTextView`.
///
/// So instead of waiting for a signal, it tries to scroll whenever either input
/// arrives — the scroll target, or the chapter's ``ChapterScrollAnchors`` (published as
/// the blocks render). Both are needed: a target can be on the chapter already on
/// screen, which produces no new anchors to trigger on.
@MainActor
@Observable
final class VerseScrollCoordinator {
    /// How long a scroll stays pending before it's abandoned, in case the requested
    /// chapter never lays out and the scroll would otherwise never complete.
    private let safetyTimeout: Duration = .seconds(2)
    /// Number of `scrollTo` attempts, one frame apart, since a large chapter's blocks
    /// lay out over several frames and the target may not exist on the first tries.
    private let scrollAttempts = 10
    /// Roughly one 60Hz frame, between scroll attempts.
    private let frameInterval: Duration = .milliseconds(16)

    /// True while a verse is requested but not yet scrolled to.
    private(set) var isScrollPending = false

    private let viewModel: BibleReaderViewModel
    private var anchors: ChapterScrollAnchors?
    private var scrollTask: Task<Void, Never>?
    private var safetyTask: Task<Void, Never>?

    /// The verse id to scroll to, resolved from the scroll target against the held
    /// anchors, or nil when not yet resolvable (no target, or the anchors aren't for the
    /// target's chapter).
    private var resolvedScrollTarget: Int? {
        guard let target = viewModel.scrollTarget, let verse = target.verseStart,
              let anchors, anchors.chapter == target.chapter else {
            return nil
        }
        return anchors.blockFirstVerse(forTargetVerse: verse)
    }

    /// True when the target's chapter is already rendered — its anchors are held. The scroll
    /// can then run off the target's arrival, without waiting for anchors to fire. This is
    /// the path a jump to a verse in the already-displayed chapter takes.
    private var isTargetChapterRendered: Bool {
        viewModel.scrollTarget?.chapter == anchors?.chapter
    }

    init(viewModel: BibleReaderViewModel) {
        self.viewModel = viewModel
    }

    /// Marks the scroll as pending and arms the safety timeout. If the target's chapter is
    /// already rendered, scrolls immediately; otherwise the scroll waits for that chapter's
    /// anchors to arrive via ``handleAnchors(_:proxy:)``.
    func handleScrollTarget(proxy: ScrollViewProxy) {
        isScrollPending = true

        safetyTask?.cancel()
        safetyTask = Task { @MainActor [weak self, safetyTimeout] in
            // swiftlint:disable:next common_debug_statements
            try? await Task.sleep(for: safetyTimeout)
            guard let self, !Task.isCancelled else {
                return
            }
            viewModel.clearScrollTarget()
            isScrollPending = false
        }

        if isTargetChapterRendered {
            scrollToResolvedTarget(proxy: proxy)
        }
    }

    /// Records the latest chapter's anchors and scrolls if they're what the target was
    /// waiting on. If they belong to a different chapter than the target — the reader
    /// navigated away while a scroll was pending — the target will never lay out, so the
    /// pending scroll is abandoned and the content revealed rather than left hidden until
    /// the safety timeout.
    func handleAnchors(_ newAnchors: ChapterScrollAnchors?, proxy: ScrollViewProxy) {
        anchors = newAnchors
        if isScrollPending, let newAnchors,
           newAnchors.chapter != viewModel.scrollTarget?.chapter {
            cancelPendingScroll()
            return
        }
        scrollToResolvedTarget(proxy: proxy)
    }

    /// Scrolls to the resolved target, if there is one, re-issuing the scroll across several
    /// frames since the target block may not exist on the first try (blocks lay out over
    /// frames) and `scrollTo` is idempotent once it does. The scroll target and pending
    /// state are held until the scroll completes — cleared together at the end — so a repeat
    /// ``handleAnchors(_:proxy:)`` mid-scroll still sees the chapter it's scrolling to.
    /// Single-flight: a new scroll cancels any pending one.
    private func scrollToResolvedTarget(proxy: ScrollViewProxy) {
        guard let verseID = resolvedScrollTarget else {
            return
        }

        safetyTask?.cancel()
        scrollTask?.cancel()
        scrollTask = Task { @MainActor [weak self, scrollAttempts, frameInterval] in
            for attempt in 0..<scrollAttempts {
                if attempt > 0 {
                    // swiftlint:disable:next common_debug_statements
                    try? await Task.sleep(for: frameInterval)
                    if Task.isCancelled {
                        return
                    }
                }
                proxy.scrollTo(verseID, anchor: .top)
            }
            self?.viewModel.clearScrollTarget()
            self?.isScrollPending = false
        }
    }

    /// Abandons the pending scroll and reveals the content, cancelling the safety timeout.
    private func cancelPendingScroll() {
        safetyTask?.cancel()
        scrollTask?.cancel()
        viewModel.clearScrollTarget()
        isScrollPending = false
    }
}
