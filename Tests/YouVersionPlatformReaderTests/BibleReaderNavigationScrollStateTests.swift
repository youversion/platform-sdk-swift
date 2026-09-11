import SwiftUI
import Testing
@testable import YouVersionPlatformReader

struct ReaderNavigationScrollStateTests {
    @Test func ignoresProgrammaticScrolling() {
        var state = ReaderNavigationScrollState()
        state.update(delta: 300, isUserScrolling: false, isAtBoundary: false)
        #expect(!state.isCompact)
    }

    @Test(arguments: [30.0, -30.0])
    func deliberateMovementInEitherDirectionCollapsesNavigation(delta: Double) {
        var state = ReaderNavigationScrollState()
        state.update(delta: delta, isUserScrolling: true, isAtBoundary: false)
        #expect(!state.isCompact)
        state.update(delta: delta, isUserScrolling: true, isAtBoundary: false)
        #expect(state.isCompact)
        state.update(delta: -delta * 2, isUserScrolling: true, isAtBoundary: false)
        #expect(state.isCompact)
    }

    @Test func boundariesAlwaysRestoreNavigation() {
        var state = ReaderNavigationScrollState()
        state.update(delta: 100, isUserScrolling: true, isAtBoundary: false)
        #expect(state.isCompact)
        state.update(delta: 0, isUserScrolling: false, isAtBoundary: true)
        #expect(!state.isCompact)
    }

    @Test func scrollingAwayFromBoundaryCanCollapseNavigationAgain() {
        var state = ReaderNavigationScrollState()
        state.update(delta: 100, isUserScrolling: true, isAtBoundary: false)
        #expect(state.isCompact)
        state.update(delta: 1, isUserScrolling: true, isAtBoundary: true)
        #expect(!state.isCompact)
        state.update(delta: -100, isUserScrolling: true, isAtBoundary: false)
        #expect(state.isCompact)
        state.endGesture()
        state.update(delta: 60, isUserScrolling: true, isAtBoundary: false)
        #expect(state.isCompact)
    }

    @Test func smallMovementsAcrossSeparateGesturesDoNotAccumulate() {
        var state = ReaderNavigationScrollState()
        state.update(delta: 40, isUserScrolling: true, isAtBoundary: false)
        state.endGesture()
        state.update(delta: 40, isUserScrolling: true, isAtBoundary: false)
        #expect(!state.isCompact)
    }
}

struct NavigationScrollGeometryTests {
    @Test(arguments: [
        (-62.0, true),
        (0.0, false),
        (293.0, false),
        (376.3333333333333, true),
        (400.0, true),
    ])
    func recognizesScrollBoundariesWithSafeAreaInsets(offset: Double, isAtBoundary: Bool) {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
            let geometry = NavigationScrollGeometry(ScrollGeometry(
                contentOffset: CGPoint(x: 0, y: offset),
                contentSize: CGSize(width: 402, height: 1167.3333333333333),
                contentInsets: EdgeInsets(top: 62, leading: 0, bottom: 83, trailing: 0),
                containerSize: CGSize(width: 402, height: 729)
            ))
            #expect(geometry.isAtBoundary == isAtBoundary)
        }
    }
}
