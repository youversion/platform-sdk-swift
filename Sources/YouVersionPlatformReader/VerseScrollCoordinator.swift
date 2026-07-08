import Observation
import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// Scrolls the reader to a requested verse. SwiftUI exposes no "chapter laid out" signal,
/// so the scroll fires when either input arrives — the scroll target, or the chapter's
/// ``ChapterScrollAnchors`` — since the target can already be on screen (no new anchors) or
/// still loading (target set before anchors).
@MainActor
@Observable
final class VerseScrollCoordinator {
    /// How long a scroll stays pending before it's abandoned, if the chapter never lays out.
    private let fallbackTimeout: Duration = .seconds(2)

    /// True while a verse is requested but not yet scrolled to.
    private(set) var isScrollPending = false

    private let viewModel: BibleReaderViewModel
    private var anchors: ChapterScrollAnchors?
    private var scrollTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?

    private var targetBlockID: Int? {
        guard let target = viewModel.scrollTargetReference, let verse = target.verseStart,
              let anchors, anchors.chapter == target.chapter else {
            return nil
        }
        return anchors.blockFirstVerse(forTargetVerse: verse)
    }

    private var isTargetChapterRendered: Bool {
        viewModel.scrollTargetReference?.chapter == anchors?.chapter
    }

    init(viewModel: BibleReaderViewModel) {
        self.viewModel = viewModel
    }

    /// Marks the scroll pending and arms the fallback. Scrolls now if the chapter is already
    /// rendered; otherwise waits for its anchors via ``handleAnchors(_:proxy:)``.
    func handleScrollTarget(proxy: ScrollViewProxy) {
        isScrollPending = true

        fallbackTask?.cancel()
        fallbackTask = Task { @MainActor [weak self, fallbackTimeout] in
            // swiftlint:disable:next common_debug_statements
            try? await Task.sleep(for: fallbackTimeout)
            guard let self, !Task.isCancelled else {
                return
            }
            viewModel.clearScrollTarget()
            isScrollPending = false
        }

        if isTargetChapterRendered {
            scrollToTargetBlock(proxy: proxy)
        }
    }

    /// Records the latest chapter's anchors and scrolls if they match the target.
    func handleAnchors(_ newAnchors: ChapterScrollAnchors?, proxy: ScrollViewProxy) {
        anchors = newAnchors
        if isScrollPending, let newAnchors,
           newAnchors.chapter != viewModel.scrollTargetReference?.chapter {
            cancelPendingScroll()
            return
        }
        scrollToTargetBlock(proxy: proxy)
    }

    /// Scrolls to the target block on the next display frame — the anchors arrive before
    /// SwiftUI commits the layout, so scrolling in the same tick lands at the chapter top.
    /// The target and pending state are held until the scroll completes so a repeat anchor
    /// fire mid-scroll still resolves. Single-flight: a new scroll cancels any pending one.
    private func scrollToTargetBlock(proxy: ScrollViewProxy) {
        guard let blockID = targetBlockID else {
            return
        }

        fallbackTask?.cancel()
        scrollTask?.cancel()
        scrollTask = Task { @MainActor [weak self] in
            await DisplayFrame().nextFrame()
            if Task.isCancelled {
                return
            }
            proxy.scrollTo(blockID, anchor: .top)
            self?.viewModel.clearScrollTarget()
            self?.isScrollPending = false
        }
    }

    /// Abandons the pending scroll and reveals the content, cancelling the fallback timeout.
    private func cancelPendingScroll() {
        fallbackTask?.cancel()
        scrollTask?.cancel()
        viewModel.clearScrollTarget()
        isScrollPending = false
    }
}

/// Suspends until the next display frame (v-sync), so a scroll runs after SwiftUI has
/// committed the current layout.
@MainActor
private final class DisplayFrame: NSObject {
    private var displayLink: CADisplayLink?
    private var continuation: CheckedContinuation<Void, Never>?

    func nextFrame() async {
        await withCheckedContinuation { continuation in
#if os(macOS)
            continuation.resume()
#else
            self.continuation = continuation
            let displayLink = CADisplayLink(target: self, selector: #selector(fire))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
#endif
        }
    }

    @objc private func fire() {
        displayLink?.invalidate()
        displayLink = nil
        continuation?.resume()
        continuation = nil
    }
}
