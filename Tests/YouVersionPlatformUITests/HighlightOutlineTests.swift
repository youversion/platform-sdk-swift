import CoreGraphics
import Testing
@testable import YouVersionPlatformUI

@Suite struct HighlightOutlineTests {
    @Test
    func singleLineBandIsPaddedByOuterPaddingOnBothSides() {
        let bands = HighlightOutline.bands(
            for: [CGRect(x: 0, y: 10, width: 100, height: 20)],
            outerPadding: 4
        )

        #expect(bands == [6...34])
    }

    @Test
    func adjacentLineBandsMeetAtTheMidpointOfTheirGap() {
        let bands = HighlightOutline.bands(
            for: [
                CGRect(x: 0, y: 0, width: 100, height: 20),
                CGRect(x: 0, y: 28, width: 100, height: 20),
                CGRect(x: 0, y: 56, width: 60, height: 20)
            ],
            outerPadding: 4
        )

        #expect(bands == [-4...24, 24...52, 52...80])
    }

    @Test
    func overlappingLinesProduceNonInvertedBands() {
        let bands = HighlightOutline.bands(
            for: [
                CGRect(x: 0, y: 0, width: 100, height: 20),
                CGRect(x: 0, y: 16, width: 100, height: 2)
            ],
            outerPadding: 0
        )

        #expect(bands.allSatisfy { $0.lowerBound <= $0.upperBound })
    }

    @Test
    func touchingRunsOfTheSameStyleMergeIntoOneSpan() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 40, maxX: 80),
                HighlightRun(style: "yellow", minX: 0, maxX: 40)
            ]],
            bands: [0...20]
        )

        #expect(groups.count == 1)
        #expect(groups.first?.lines == [[HighlightSpan(minX: 0, maxX: 80, band: 0...20)]])
    }

    @Test
    func touchingRunsOfDifferentStylesShareTheirMeetingEdge() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 0, maxX: 40),
                HighlightRun(style: "green", minX: 40, maxX: 80)
            ]],
            bands: [0...20]
        )

        let yellow = groups.first { $0.style == "yellow" }?.lines.first?.first
        let green = groups.first { $0.style == "green" }?.lines.first?.first
        #expect(yellow?.isTrailingEdgeShared == true)
        #expect(yellow?.isLeadingEdgeShared == false)
        #expect(green?.isLeadingEdgeShared == true)
        #expect(green?.isTrailingEdgeShared == false)
    }

    @Test
    func horizontallyOverlappingSpansOnConsecutiveLinesFormOneChain() {
        let first = HighlightSpan(minX: 50, maxX: 100, band: 0...20)
        let second = HighlightSpan(minX: 0, maxX: 100, band: 20...40)
        let third = HighlightSpan(minX: 0, maxX: 30, band: 40...60)

        let chains = HighlightOutline.chains([[first], [second], [third]])

        #expect(chains == [[first, second, third]])
    }

    @Test
    func spansThatDoNotOverlapHorizontallyFormSeparateChains() {
        let first = HighlightSpan(minX: 60, maxX: 100, band: 0...20)
        let second = HighlightSpan(minX: 0, maxX: 40, band: 20...40)

        let chains = HighlightOutline.chains([[first], [second]])

        #expect(chains.count == 2)
    }

    @Test
    func spansThatOnlyTouchOncePaddedFormOneChain() {
        let first = HighlightSpan(minX: 42, maxX: 100, band: 0...20)
        let second = HighlightSpan(minX: 0, maxX: 40, band: 20...40)

        let chains = HighlightOutline.chains([[first], [second]], padding: 2)

        #expect(chains == [[first, second]])
    }

    @Test
    func singleSpanOutlineIsItsPaddedRectangle() {
        let corners = HighlightOutline.corners(
            of: [HighlightSpan(minX: 10, maxX: 50, band: 0...20)],
            padding: 2
        )

        #expect(corners == [
            CGPoint(x: 52, y: 0),
            CGPoint(x: 52, y: 20),
            CGPoint(x: 8, y: 20),
            CGPoint(x: 8, y: 0)
        ])
    }

    @Test
    func alignedEdgesAcrossLinesCollapseIntoOneStraightSide() {
        let corners = HighlightOutline.corners(
            of: [
                HighlightSpan(minX: 50, maxX: 100, band: 0...20),
                HighlightSpan(minX: 0, maxX: 100, band: 20...40)
            ],
            padding: 0
        )

        #expect(corners == [
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 40),
            CGPoint(x: 0, y: 40),
            CGPoint(x: 0, y: 20),
            CGPoint(x: 50, y: 20),
            CGPoint(x: 50, y: 0)
        ])
    }

    @Test
    func sharedEdgesAreNotPadded() {
        let corners = HighlightOutline.corners(
            of: [HighlightSpan(minX: 10, maxX: 50, band: 0...20, isTrailingEdgeShared: true)],
            padding: 2
        )

        #expect(corners == [
            CGPoint(x: 50, y: 0),
            CGPoint(x: 50, y: 20),
            CGPoint(x: 8, y: 20),
            CGPoint(x: 8, y: 0)
        ])
    }

    @Test
    func sharedEdgesKeepRoundedCorners() {
        let path = HighlightOutline.path(
            of: HighlightOutline.corners(
                of: [HighlightSpan(minX: 0, maxX: 50, band: 0...20, isTrailingEdgeShared: true)],
                padding: 0
            ),
            cornerRadius: 4
        )

        #expect(!path.contains(CGPoint(x: 49.5, y: 0.5)))
        #expect(path.contains(CGPoint(x: 49.5, y: 10)))
    }

    @Test
    func trailingWhitespaceBeforeAnUnhighlightedRunIsNotPainted() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 0, maxX: 40),
                HighlightRun(style: "yellow", minX: 40, maxX: 45, isWhitespace: true)
            ]],
            bands: [0...20]
        )

        #expect(groups.first?.lines == [[HighlightSpan(minX: 0, maxX: 40, band: 0...20)]])
    }

    @Test
    func whitespaceBetweenRunsOfTheSameStyleIsPainted() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 0, maxX: 40),
                HighlightRun(style: "yellow", minX: 40, maxX: 45, isWhitespace: true),
                HighlightRun(style: "yellow", minX: 45, maxX: 80)
            ]],
            bands: [0...20]
        )

        #expect(groups.first?.lines == [[HighlightSpan(minX: 0, maxX: 80, band: 0...20)]])
    }

    @Test
    func whitespaceBetweenDifferentStylesIsSplitAtItsMiddle() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 0, maxX: 40),
                HighlightRun(style: "yellow", minX: 40, maxX: 46, isWhitespace: true),
                HighlightRun(style: "green", minX: 46, maxX: 80)
            ]],
            bands: [0...20]
        )

        let yellow = groups.first { $0.style == "yellow" }?.lines.first?.first
        let green = groups.first { $0.style == "green" }?.lines.first?.first
        #expect(yellow?.maxX == 43)
        #expect(yellow?.isTrailingEdgeShared == true)
        #expect(green?.minX == 43)
        #expect(green?.isLeadingEdgeShared == true)
    }

    @Test
    func runAtLineStartMakesItsSpanFlush() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[HighlightRun(style: "yellow", minX: 0, maxX: 40, isLeadingEdgeFlush: true)]],
            bands: [0...20]
        )

        #expect(groups.first?.lines.first?.first?.isLeadingEdgeFlush == true)
    }

    @Test
    func flushSpansInAChainShareTheLeftMostLeadingEdge() {
        let chain = HighlightOutline.flushAligned([
            HighlightSpan(minX: 30, maxX: 100, band: 0...20),
            HighlightSpan(minX: 16, maxX: 100, band: 20...40, isLeadingEdgeFlush: true),
            HighlightSpan(minX: 32, maxX: 100, band: 40...60, isLeadingEdgeFlush: true)
        ])

        #expect(chain.map(\.minX) == [30, 16, 16])
    }

    @Test
    func runAtRightToLeftLineStartMakesItsSpanTrailingEdgeFlush() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 60, maxX: 80),
                HighlightRun(style: "yellow", minX: 80, maxX: 100, isTrailingEdgeFlush: true)
            ]],
            bands: [0...20]
        )

        #expect(groups.first?.lines.first?.first?.isTrailingEdgeFlush == true)
        #expect(groups.first?.lines.first?.first?.isLeadingEdgeFlush == false)
    }

    @Test
    func trailingFlushSpansInAChainShareTheRightMostTrailingEdge() {
        let chain = HighlightOutline.flushAligned([
            HighlightSpan(minX: 0, maxX: 70, band: 0...20),
            HighlightSpan(minX: 0, maxX: 84, band: 20...40, isTrailingEdgeFlush: true),
            HighlightSpan(minX: 40, maxX: 68, band: 40...60, isTrailingEdgeFlush: true)
        ])

        #expect(chain.map(\.minX) == [0, 0, 40])
        #expect(chain.map(\.maxX) == [70, 84, 84])
    }

    @Test
    func outlineLeavesNoUnpaintedSpaceBetweenLines() {
        let chain = [
            HighlightSpan(minX: 0, maxX: 100, band: 0...20),
            HighlightSpan(minX: 0, maxX: 70, band: 20...40)
        ]
        let path = HighlightOutline.path(
            of: HighlightOutline.corners(of: chain, padding: 0),
            cornerRadius: 4
        )

        #expect(path.contains(CGPoint(x: 0.5, y: 20)))
        #expect(path.contains(CGPoint(x: 69.5, y: 20.5)))
        #expect(path.contains(CGPoint(x: 90, y: 19.5)))
    }

    @Test
    func gapBetweenBlocksIsFilledWhenBothEdgeLinesAreHighlighted() {
        let bands = HighlightOutline.bands(
            for: [
                [line(y: 0, highlighted: true)],
                [line(y: 40, highlighted: true)]
            ],
            outerPadding: 4
        )

        #expect(bands == [[-4...30], [30...64]])
    }

    @Test
    func gapBetweenBlocksIsKeptWhenAnEdgeLineIsNotHighlighted() {
        let bands = HighlightOutline.bands(
            for: [
                [line(y: 0, highlighted: true)],
                [line(y: 40, highlighted: false)]
            ],
            outerPadding: 4
        )

        #expect(bands == [[-4...24], [36...64]])
    }

    @Test
    func verticallyOverlappingBlocksAreNotJoined() {
        let bands = HighlightOutline.bands(
            for: [
                [line(y: 0, highlighted: true)],
                [line(y: 10, highlighted: true)]
            ],
            outerPadding: 4
        )

        #expect(bands == [[-4...24], [6...34]])
    }

    @Test
    func highlightSpanningBlocksIsOneShape() {
        let highlights = HighlightOutline.paths(
            for: [
                [line(y: 0, highlighted: true)],
                [line(y: 40, minX: 20, highlighted: true)]
            ],
            outerPadding: 4,
            padding: 2,
            cornerRadius: 4
        )

        #expect(highlights.count == 1)
        let path = highlights.first?.path
        #expect(path?.contains(CGPoint(x: 50, y: 30)) == true)
        #expect(path?.contains(CGPoint(x: 50, y: 22)) == true)
        #expect(path?.contains(CGPoint(x: 50, y: 38)) == true)
    }

    @Test
    func spanBranchingIntoTwoSpansOnTheNextLineLeavesNoGapAtTheJoin() {
        let highlights = HighlightOutline.paths(
            for: [[
                line(y: 0, highlighted: true),
                HighlightLine(
                    bounds: CGRect(x: 0, y: 28, width: 100, height: 20),
                    runs: [
                        HighlightRun(style: "yellow", minX: 0, maxX: 40),
                        HighlightRun(style: "yellow", minX: 60, maxX: 100)
                    ]
                )
            ]],
            outerPadding: 4,
            padding: 2,
            cornerRadius: 4
        )

        let path = highlights.first?.path
        #expect(path?.contains(CGPoint(x: -1.5, y: 23.5)) == true)
        #expect(path?.contains(CGPoint(x: -1.5, y: 24.5)) == true)
        #expect(path?.contains(CGPoint(x: 41.5, y: 24.5)) == true)
        #expect(path?.contains(CGPoint(x: 58.5, y: 24.5)) == true)
        #expect(path?.contains(CGPoint(x: 101.5, y: 23.5)) == true)
        #expect(path?.contains(CGPoint(x: 101.5, y: 24.5)) == true)
        #expect(path?.contains(CGPoint(x: 50, y: 30)) == false)
    }

    @Test
    func twoSpansMergingIntoOneSpanOnTheNextLineLeaveNoGapAtTheJoin() {
        let highlights = HighlightOutline.paths(
            for: [[
                HighlightLine(
                    bounds: CGRect(x: 0, y: 0, width: 100, height: 20),
                    runs: [
                        HighlightRun(style: "yellow", minX: 0, maxX: 40),
                        HighlightRun(style: "yellow", minX: 60, maxX: 100)
                    ]
                ),
                line(y: 28, highlighted: true)
            ]],
            outerPadding: 4,
            padding: 2,
            cornerRadius: 4
        )

        let path = highlights.first?.path
        #expect(path?.contains(CGPoint(x: -1.5, y: 23.5)) == true)
        #expect(path?.contains(CGPoint(x: 41.5, y: 23.5)) == true)
        #expect(path?.contains(CGPoint(x: 58.5, y: 23.5)) == true)
        #expect(path?.contains(CGPoint(x: 101.5, y: 24.5)) == true)
        #expect(path?.contains(CGPoint(x: 50, y: 18)) == false)
    }

    @Test
    func dimmedRunTouchingAnUndimmedRunOfTheSameStyleStaysOneSpan() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 0, maxX: 40),
                HighlightRun(style: "yellow", minX: 40, maxX: 80, isDimmed: true)
            ]],
            bands: [0...20]
        )

        #expect(groups.count == 1)
        #expect(groups.first?.lines == [[HighlightSpan(minX: 0, maxX: 80, band: 0...20, dimmedRanges: [40...80])]])
    }

    @Test
    func whitespaceBetweenDimmedAndUndimmedRunsIsSplitAtItsMiddle() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 0, maxX: 40),
                HighlightRun(style: "yellow", minX: 40, maxX: 46, isWhitespace: true),
                HighlightRun(style: "yellow", minX: 46, maxX: 80, isDimmed: true)
            ]],
            bands: [0...20]
        )

        #expect(groups.first?.lines == [[HighlightSpan(minX: 0, maxX: 80, band: 0...20, dimmedRanges: [43...80])]])
    }

    @Test
    func separateDimmedRunsKeepSeparateRangesAndTouchingOnesMerge() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 0, maxX: 20, isDimmed: true),
                HighlightRun(style: "yellow", minX: 20, maxX: 50),
                HighlightRun(style: "yellow", minX: 50, maxX: 80, isDimmed: true),
                HighlightRun(style: "yellow", minX: 80, maxX: 100, isDimmed: true)
            ]],
            bands: [0...20]
        )

        #expect(groups.first?.lines == [[HighlightSpan(minX: 0, maxX: 100, band: 0...20, dimmedRanges: [0...20, 50...100])]])
    }

    @Test
    func whitespaceBetweenTwoDimmedRunsStaysDimmed() {
        let groups = HighlightOutline.spansByStyle(
            lines: [[
                HighlightRun(style: "yellow", minX: 0, maxX: 40, isDimmed: true),
                HighlightRun(style: "yellow", minX: 40, maxX: 46, isWhitespace: true),
                HighlightRun(style: "yellow", minX: 46, maxX: 80, isDimmed: true)
            ]],
            bands: [0...20]
        )

        #expect(groups.first?.lines == [[HighlightSpan(minX: 0, maxX: 80, band: 0...20, dimmedRanges: [0...80])]])
    }

    @Test
    func flushAlignmentCarriesALeadingDimmedRangeWithTheEdge() {
        let chain = HighlightOutline.flushAligned([
            HighlightSpan(minX: 16, maxX: 100, band: 0...20, isLeadingEdgeFlush: true),
            HighlightSpan(minX: 32, maxX: 100, band: 20...40, isLeadingEdgeFlush: true, dimmedRanges: [32...60])
        ])

        #expect(chain.last?.dimmedRanges == [16...60])
    }

    @Test
    func flushAlignmentCarriesATrailingDimmedRangeWithTheEdge() {
        let chain = HighlightOutline.flushAligned([
            HighlightSpan(minX: 0, maxX: 84, band: 0...20, isTrailingEdgeFlush: true),
            HighlightSpan(minX: 0, maxX: 68, band: 20...40, isTrailingEdgeFlush: true, dimmedRanges: [40...68])
        ])

        #expect(chain.last?.dimmedRanges == [40...84])
    }

    @Test
    func dimmedAreaCoversOnlyTheDimmedPartOfTheShape() {
        let highlights = HighlightOutline.paths(
            for: [[
                HighlightLine(
                    bounds: CGRect(x: 0, y: 0, width: 100, height: 20),
                    runs: [
                        HighlightRun(style: "yellow", minX: 0, maxX: 50),
                        HighlightRun(style: "yellow", minX: 50, maxX: 100, isDimmed: true)
                    ]
                ),
                HighlightLine(
                    bounds: CGRect(x: 0, y: 28, width: 100, height: 20),
                    runs: [HighlightRun(style: "yellow", minX: 0, maxX: 100)]
                )
            ]],
            outerPadding: 4,
            padding: 2,
            cornerRadius: 4
        )

        #expect(highlights.count == 1)
        let dimmedArea = highlights.first?.dimmedArea
        #expect(dimmedArea?.contains(CGPoint(x: 75, y: 10)) == true)
        #expect(dimmedArea?.contains(CGPoint(x: 101, y: 10)) == true)
        #expect(dimmedArea?.contains(CGPoint(x: 75, y: -4.5)) == true)
        #expect(dimmedArea?.contains(CGPoint(x: 49, y: 10)) == false)
        #expect(dimmedArea?.contains(CGPoint(x: 75, y: 24.5)) == false)
    }

    @Test
    func dimmedAreaLeavesTheUndimmedGapBetweenDimmedRangesAndReachesThePaddedEdges() {
        let highlights = HighlightOutline.paths(
            for: [[
                HighlightLine(
                    bounds: CGRect(x: 0, y: 0, width: 100, height: 20),
                    runs: [
                        HighlightRun(style: "yellow", minX: 0, maxX: 30, isDimmed: true),
                        HighlightRun(style: "yellow", minX: 30, maxX: 70),
                        HighlightRun(style: "yellow", minX: 70, maxX: 100, isDimmed: true)
                    ]
                )
            ]],
            outerPadding: 4,
            padding: 2,
            cornerRadius: 4
        )

        let dimmedArea = highlights.first?.dimmedArea
        #expect(dimmedArea?.contains(CGPoint(x: -1, y: 10)) == true)
        #expect(dimmedArea?.contains(CGPoint(x: 29, y: 10)) == true)
        #expect(dimmedArea?.contains(CGPoint(x: 31, y: 10)) == false)
        #expect(dimmedArea?.contains(CGPoint(x: 50, y: 10)) == false)
        #expect(dimmedArea?.contains(CGPoint(x: 69, y: 10)) == false)
        #expect(dimmedArea?.contains(CGPoint(x: 85, y: 10)) == true)
        #expect(dimmedArea?.contains(CGPoint(x: 101, y: 10)) == true)
    }

    @Test
    func undimmedHighlightHasNoDimmedArea() {
        let highlights = HighlightOutline.paths(
            for: [[line(y: 0, highlighted: true)]],
            outerPadding: 4,
            padding: 2,
            cornerRadius: 4
        )

        #expect(highlights.first?.dimmedArea.isEmpty == true)
    }

    private func line(y: CGFloat, minX: CGFloat = 0, highlighted: Bool) -> HighlightLine<String> {
        HighlightLine(
            bounds: CGRect(x: minX, y: y, width: 100, height: 20),
            runs: highlighted ? [HighlightRun(style: "yellow", minX: minX, maxX: minX + 100)] : []
        )
    }
}
