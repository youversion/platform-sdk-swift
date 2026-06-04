import Observation
import SwiftUI
import Testing
@testable import YouVersionPlatformReader

@MainActor
@Suite(.serialized) struct BibleReaderScrollObservationTests {
    private typealias Support = BibleReaderViewModelTestSupport
    private final class InvalidationFlag: @unchecked Sendable {
        var didInvalidate = false
    }

    @Test
    func lastScrollOffsetDoesNotInvalidateObservationTracking() {
        let scrollDownOffsets = stride(from: CGFloat(0), through: CGFloat(-1_000), by: CGFloat(-20)).map(\.self)
        let scrollUpOffsets = stride(from: CGFloat(-1_000), through: CGFloat(0), by: CGFloat(20)).map(\.self)
        let offsets = scrollDownOffsets + scrollUpOffsets

        let invalidations = countInvalidations(read: { viewModel in
            _ = viewModel.lastScrollOffset
        }, mutate: { viewModel, offset in
            viewModel.handleScroll(offset: offset)
        }, offsets: offsets)

        #expect(invalidations == 0)
    }

    private func countInvalidations(
        read: (BibleReaderViewModel) -> Void,
        mutate: (BibleReaderViewModel, CGFloat) -> Void,
        offsets: [CGFloat]
    ) -> Int {
        let viewModel = Support.makeViewModel()
        viewModel.showChrome = true
        viewModel.lastScrollOffset = 0

        return offsets.reduce(into: 0) { invalidations, offset in
            let invalidationFlag = InvalidationFlag()
            withObservationTracking {
                read(viewModel)
            } onChange: {
                invalidationFlag.didInvalidate = true
            }

            mutate(viewModel, offset)

            if invalidationFlag.didInvalidate {
                invalidations += 1
            }
        }
    }
}
