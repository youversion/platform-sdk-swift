import SwiftUI

struct HighlightRun<Style: Equatable> {
    let style: Style
    let minX: CGFloat
    let maxX: CGFloat
    var isAtLineStart = false
}

struct HighlightCorner: Equatable {
    let point: CGPoint
    let isRounded: Bool
}

struct HighlightLine<Style: Equatable> {
    let bounds: CGRect
    let runs: [HighlightRun<Style>]
}

struct HighlightSpan: Equatable {
    var minX: CGFloat
    var maxX: CGFloat
    var band: ClosedRange<CGFloat>
    var isLeadingEdgeShared = false
    var isTrailingEdgeShared = false
    var isLeadingEdgeFlush = false
}

enum HighlightOutline {
    private static let tolerance: CGFloat = 0.5

    static func bands(for lineBounds: [CGRect], outerPadding: CGFloat) -> [ClosedRange<CGFloat>] {
        lineBounds.indices.map { index in
            let line = lineBounds[index]
            let top = index == lineBounds.startIndex
                ? line.minY - outerPadding
                : (lineBounds[index - 1].maxY + line.minY) / 2
            let bottom = index == lineBounds.index(before: lineBounds.endIndex)
                ? line.maxY + outerPadding
                : (line.maxY + lineBounds[index + 1].minY) / 2
            return top...max(top, bottom)
        }
    }

    static func bands<Style: Equatable>(
        for blocks: [[HighlightLine<Style>]],
        outerPadding: CGFloat
    ) -> [[ClosedRange<CGFloat>]] {
        var bandsByBlock = blocks.map { bands(for: $0.map(\.bounds), outerPadding: outerPadding) }
        for index in blocks.indices.dropFirst() {
            guard let upper = blocks[index - 1].last,
                  let lower = blocks[index].first,
                  !upper.runs.isEmpty,
                  !lower.runs.isEmpty,
                  upper.bounds.maxY <= lower.bounds.minY + tolerance,
                  let upperBand = bandsByBlock[index - 1].last,
                  let lowerBand = bandsByBlock[index].first else { continue }
            let meetingPoint = (upper.bounds.maxY + lower.bounds.minY) / 2
            bandsByBlock[index - 1][bandsByBlock[index - 1].count - 1] = upperBand.lowerBound...max(upperBand.lowerBound, meetingPoint)
            bandsByBlock[index][0] = min(meetingPoint, lowerBand.upperBound)...lowerBand.upperBound
        }
        return bandsByBlock
    }

    static func paths<Style: Equatable>(
        for blocks: [[HighlightLine<Style>]],
        outerPadding: CGFloat,
        padding: CGFloat,
        cornerRadius: CGFloat
    ) -> [(style: Style, path: Path)] {
        let lines = Array(blocks.joined())
        let bands = Array(bands(for: blocks, outerPadding: outerPadding).joined())
        return spansByStyle(lines: lines.map(\.runs), bands: bands).map { highlight in
            var path = Path()
            for chain in chains(highlight.lines, padding: padding) {
                path.addPath(self.path(of: corners(of: flushAligned(chain), padding: padding), cornerRadius: cornerRadius))
            }
            return (highlight.style, path)
        }
    }

    static func spansByStyle<Style: Equatable>(
        lines: [[HighlightRun<Style>]],
        bands: [ClosedRange<CGFloat>]
    ) -> [(style: Style, lines: [[HighlightSpan]])] {
        let lineCount = min(lines.count, bands.count)
        var result: [(style: Style, lines: [[HighlightSpan]])] = []
        for lineIndex in 0..<lineCount {
            for (style, span) in mergedSpans(lines[lineIndex], band: bands[lineIndex]) {
                if let index = result.firstIndex(where: { $0.style == style }) {
                    result[index].lines[lineIndex].append(span)
                } else {
                    var spansByLine = Array(repeating: [HighlightSpan](), count: lineCount)
                    spansByLine[lineIndex].append(span)
                    result.append((style, spansByLine))
                }
            }
        }
        return result
    }

    static func chains(_ lines: [[HighlightSpan]], padding: CGFloat = 0) -> [[HighlightSpan]] {
        var finished: [[HighlightSpan]] = []
        var open: [[HighlightSpan]] = []
        for line in lines {
            var consumed = Set<Int>()
            var continuing: [[HighlightSpan]] = []
            for span in line {
                let predecessors = open.indices.filter { index in
                    open[index].last.map { touches($0, span, padding: padding) } ?? false
                }
                if predecessors.count == 1,
                   let index = predecessors.first,
                   let tail = open[index].last,
                   line.filter({ touches(tail, $0, padding: padding) }).count == 1 {
                    continuing.append(open[index] + [span])
                    consumed.insert(index)
                } else {
                    continuing.append([span])
                }
            }
            finished += open.indices.filter { !consumed.contains($0) }.map { open[$0] }
            open = continuing
        }
        return finished + open
    }

    static func flushAligned(_ chain: [HighlightSpan]) -> [HighlightSpan] {
        guard let leadingEdge = chain.filter(\.isLeadingEdgeFlush).map(\.minX).min() else { return chain }
        return chain.map { span in
            var span = span
            if span.isLeadingEdgeFlush {
                span.minX = leadingEdge
            }
            return span
        }
    }

    static func corners(of chain: [HighlightSpan], padding: CGFloat) -> [HighlightCorner] {
        let edges = chain.map { paddedEdges(of: $0, padding: padding) }
        var corners: [HighlightCorner] = []
        for (span, edge) in zip(chain, edges) {
            let isRounded = !span.isTrailingEdgeShared
            corners.append(HighlightCorner(point: CGPoint(x: edge.maxX, y: span.band.lowerBound), isRounded: isRounded))
            corners.append(HighlightCorner(point: CGPoint(x: edge.maxX, y: span.band.upperBound), isRounded: isRounded))
        }
        for (span, edge) in zip(chain, edges).reversed() {
            let isRounded = !span.isLeadingEdgeShared
            corners.append(HighlightCorner(point: CGPoint(x: edge.minX, y: span.band.upperBound), isRounded: isRounded))
            corners.append(HighlightCorner(point: CGPoint(x: edge.minX, y: span.band.lowerBound), isRounded: isRounded))
        }
        return simplified(corners)
    }

    static func path(of corners: [HighlightCorner], cornerRadius: CGFloat) -> Path {
        var path = Path()
        guard corners.count >= 3 else { return path }
        let count = corners.count
        let last = corners[count - 1].point
        path.move(to: CGPoint(x: (last.x + corners[0].point.x) / 2, y: (last.y + corners[0].point.y) / 2))
        for index in corners.indices {
            let previous = corners[(index + count - 1) % count].point
            let corner = corners[index]
            let next = corners[(index + 1) % count].point
            let radius = corner.isRounded
                ? min(cornerRadius, distance(previous, corner.point) / 2, distance(corner.point, next) / 2)
                : 0
            if radius > 0 {
                path.addArc(tangent1End: corner.point, tangent2End: next, radius: radius)
            } else {
                path.addLine(to: corner.point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func mergedSpans<Style: Equatable>(
        _ runs: [HighlightRun<Style>],
        band: ClosedRange<CGFloat>
    ) -> [(style: Style, span: HighlightSpan)] {
        var merged: [(style: Style, span: HighlightSpan)] = []
        for run in runs.sorted(by: { $0.minX < $1.minX }) {
            if let last = merged.last, last.style == run.style, run.minX <= last.span.maxX + tolerance {
                merged[merged.count - 1].span.maxX = max(last.span.maxX, run.maxX)
            } else {
                merged.append((
                    run.style,
                    HighlightSpan(minX: run.minX, maxX: run.maxX, band: band, isLeadingEdgeFlush: run.isAtLineStart)
                ))
            }
        }
        for index in merged.indices.dropFirst() {
            let previous = merged[index - 1]
            if previous.style != merged[index].style && merged[index].span.minX - previous.span.maxX <= tolerance {
                merged[index - 1].span.isTrailingEdgeShared = true
                merged[index].span.isLeadingEdgeShared = true
            }
        }
        return merged
    }

    private static func paddedEdges(of span: HighlightSpan, padding: CGFloat) -> (minX: CGFloat, maxX: CGFloat) {
        (
            minX: span.isLeadingEdgeShared ? span.minX : span.minX - padding,
            maxX: span.isTrailingEdgeShared ? span.maxX : span.maxX + padding
        )
    }

    private static func overlaps(_ lhs: HighlightSpan, _ rhs: HighlightSpan, padding: CGFloat) -> Bool {
        let lhsEdges = paddedEdges(of: lhs, padding: padding)
        let rhsEdges = paddedEdges(of: rhs, padding: padding)
        return min(lhsEdges.maxX, rhsEdges.maxX) - max(lhsEdges.minX, rhsEdges.minX) > tolerance
    }

    private static func touches(_ upper: HighlightSpan, _ lower: HighlightSpan, padding: CGFloat) -> Bool {
        abs(upper.band.upperBound - lower.band.lowerBound) <= tolerance && overlaps(upper, lower, padding: padding)
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }

    private static func isSamePoint(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
        distance(lhs, rhs) <= tolerance
    }

    private static func isCollinear(_ first: CGPoint, _ middle: CGPoint, _ last: CGPoint) -> Bool {
        (abs(first.x - middle.x) <= tolerance && abs(middle.x - last.x) <= tolerance)
            || (abs(first.y - middle.y) <= tolerance && abs(middle.y - last.y) <= tolerance)
    }

    private static func simplified(_ corners: [HighlightCorner]) -> [HighlightCorner] {
        var result = corners
        var changed = true
        while changed && result.count >= 3 {
            changed = false
            for index in result.indices {
                let count = result.count
                let previous = result[(index + count - 1) % count].point
                let next = result[(index + 1) % count].point
                let point = result[index].point
                if isSamePoint(previous, point) || isCollinear(previous, point, next) {
                    result.remove(at: index)
                    changed = true
                    break
                }
            }
        }
        return result
    }
}
