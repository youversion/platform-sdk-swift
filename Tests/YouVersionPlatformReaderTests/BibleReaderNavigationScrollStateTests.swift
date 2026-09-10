import Testing
@testable import YouVersionPlatformReader

struct ReaderNavigationScrollStateTests {
    @Test func ignoresProgrammaticScrolling() {
        var state = ReaderNavigationScrollState()
        state.update(delta: 300, isUserScrolling: false, isAtBoundary: false)
        #expect(!state.isCompact)
    }

    @Test func accumulatesDeliberateMovementAndRestoresOnReverse() {
        var state = ReaderNavigationScrollState()
        state.update(delta: 30, isUserScrolling: true, isAtBoundary: false)
        #expect(!state.isCompact)
        state.update(delta: 30, isUserScrolling: true, isAtBoundary: false)
        #expect(state.isCompact)
        state.update(delta: -60, isUserScrolling: true, isAtBoundary: false)
        #expect(!state.isCompact)
    }

    @Test func boundariesAlwaysRestoreNavigation() {
        var state = ReaderNavigationScrollState()
        state.update(delta: 100, isUserScrolling: true, isAtBoundary: false)
        #expect(state.isCompact)
        state.update(delta: 0, isUserScrolling: false, isAtBoundary: true)
        #expect(!state.isCompact)
    }

    @Test func smallMovementsAcrossSeparateGesturesDoNotAccumulate() {
        var state = ReaderNavigationScrollState()
        state.update(delta: 40, isUserScrolling: true, isAtBoundary: false)
        state.endGesture()
        state.update(delta: 40, isUserScrolling: true, isAtBoundary: false)
        #expect(!state.isCompact)
    }
}
