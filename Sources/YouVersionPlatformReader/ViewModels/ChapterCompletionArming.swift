import Foundation

/// Decides when the reader has finished a chapter.
///
/// A chapter counts once the reader has seen its top and then reached its
/// bottom. The subtlety is a chapter that fits on one screen: its top and
/// bottom are both visible the whole time, so it must not count again every
/// time the layout settles, the reader reappears, or a programmatic scroll
/// runs.
///
/// Only an observed position changes the arming. Nothing may assert "the top
/// was passed" without having seen the top leave the viewport, which is what
/// would let a one-screen chapter record itself repeatedly.
///
/// The reader reappearing is not an observed position, so it neither arms nor
/// disarms. A chapter opened at its top and left half-read still counts once
/// the reader returns and reaches the bottom, while a chapter already counted
/// stays disarmed.
struct ChapterCompletionArming: Equatable {
    private var seenTop: Bool
    private var scrolledPastTop = false

    init(opensAtChapterTop: Bool) {
        seenTop = opensAtChapterTop
    }

    /// Whether reaching the bottom should count the chapter now.
    var isArmed: Bool {
        seenTop
    }

    /// A different chapter is being shown.
    mutating func reset(opensAtChapterTop: Bool) {
        seenTop = opensAtChapterTop
        scrolledPastTop = false
    }

    /// A programmatic scroll is running. Jumping is not reading, so the chapter
    /// is disarmed until the top is observed again.
    mutating func onProgrammaticScroll() {
        seenTop = false
    }

    /// The content's top edge in the viewport: zero at the top, negative once
    /// it has scrolled above the viewport.
    mutating func onLeadingEdge(_ offset: CGFloat) {
        guard !seenTop else {
            return
        }
        if offset < 0 {
            scrolledPastTop = true
        } else if scrolledPastTop {
            seenTop = true
        }
    }

    /// The chapter has just been counted. Another count requires the top to
    /// leave the viewport and come back.
    mutating func consume() {
        seenTop = false
        scrolledPastTop = false
    }
}
