import SwiftUI

struct HighlightRun<Style: Equatable> {
    let style: Style
    let minX: CGFloat
    let maxX: CGFloat
    var isLeadingEdgeFlush = false
    var isTrailingEdgeFlush = false
    var isWhitespace = false
    var isDimmed = false
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
    var isTrailingEdgeFlush = false
    var dimmedRanges: [ClosedRange<CGFloat>] = []
}

enum HighlightOutline {
    private static let tolerance: CGFloat = 0.5
    private static let dimmedAreaBleed: CGFloat = 1

    /// Returns the vertical band each line's highlight fills, so neighboring lines meet with no gap.
    ///
    /// Adjacent lines split the space between them at the midpoint. The first and last lines
    /// extend `outerPadding` beyond their bounds.
    /// - Parameters:
    ///   - lineBounds: The typographic bounds of each line, top to bottom, in one coordinate space.
    ///   - outerPadding: The distance the first line's band extends above it and the last line's band extends below it.
    /// - Returns: One `minY...maxY` range per line, in the same coordinate space as `lineBounds`.
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

    /// Returns the vertical bands for every line in every block, joining highlighted lines across block boundaries.
    ///
    /// When the last line of one block and the first line of the next both hold highlights, their
    /// bands meet at the midpoint between them instead of each extending by `outerPadding`.
    /// - Parameters:
    ///   - blocks: The lines of each text block, top to bottom, in one coordinate space.
    ///   - outerPadding: The distance a block's outer bands extend beyond its first and last lines.
    /// - Returns: One `minY...maxY` range per line, grouped the same way as `blocks`.
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
                  let lowerBand = bandsByBlock[index].first else {
                continue
            }
            let meetingPoint = (upper.bounds.maxY + lower.bounds.minY) / 2
            bandsByBlock[index - 1][bandsByBlock[index - 1].count - 1] = upperBand.lowerBound...max(upperBand.lowerBound, meetingPoint)
            bandsByBlock[index][0] = min(meetingPoint, lowerBand.upperBound)...lowerBand.upperBound
        }
        return bandsByBlock
    }

    /// Returns one rounded outline per highlight style that covers every highlighted run with no gaps between lines.
    /// - Parameters:
    ///   - blocks: The lines of each text block, top to bottom, with run positions in one coordinate space.
    ///   - outerPadding: The distance a block's outer bands extend beyond its first and last lines.
    ///   - padding: The distance an outline extends past the leading and trailing edges of its runs,
    ///     except where it meets a highlight of another style.
    ///   - cornerRadius: The radius of the outline's rounded corners.
    /// - Returns: For each style, the outline to fill and the part of it that covers dimmed runs.
    static func paths<Style: Equatable>(
        for blocks: [[HighlightLine<Style>]],
        outerPadding: CGFloat,
        padding: CGFloat,
        cornerRadius: CGFloat
    ) -> [(style: Style, path: Path, dimmedArea: Path)] {
        let lines = Array(blocks.joined())
        let bands = Array(bands(for: blocks, outerPadding: outerPadding).joined())
        return spansByStyle(lines: lines.map(\.runs), bands: bands).map { highlight in
            let chains = chains(highlight.lines, padding: padding).map(flushAligned)
            let outlines = chains.map { self.path(of: corners(of: $0, padding: padding), cornerRadius: cornerRadius) }
            let joins = bridges(between: chains, padding: padding, cornerRadius: cornerRadius).map { self.path(of: $0, cornerRadius: 0) }
            let path = (outlines + joins).reduce(into: Path()) { $0.addPath($1) }
            return (highlight.style, path, dimmedArea(of: chains, padding: padding))
        }
    }

    /// Merges each line's runs into spans and groups them by style.
    /// - Parameters:
    ///   - lines: The highlighted runs on each line, top to bottom.
    ///   - bands: The vertical band of each line, from `bands(for:outerPadding:)`.
    /// - Returns: For each style, in order of first appearance, the spans of that style on each line.
    ///   Every style has one entry per line, which is empty when the line has no span of that style.
    static func spansByStyle<Style: Equatable>(
        lines: [[HighlightRun<Style>]],
        bands: [ClosedRange<CGFloat>]
    ) -> [(style: Style, lines: [[HighlightSpan]])] {
        let lineCount = min(lines.count, bands.count)
        return (0..<lineCount).reduce(into: []) { result, lineIndex in
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
    }

    /// Groups spans on consecutive lines into chains that can be drawn as one outline.
    ///
    /// A span continues the chain above it only when the two spans touch and neither touches any other
    /// span on the other's line. Every other span starts a new chain.
    /// - Parameters:
    ///   - lines: The spans of one style on each line, top to bottom.
    ///   - padding: The distance a span extends past its leading and trailing edges when checking whether spans touch.
    /// - Returns: The chains, each listing its spans top to bottom.
    static func chains(_ lines: [[HighlightSpan]], padding: CGFloat = 0) -> [[HighlightSpan]] {
        let result = lines.reduce(into: (finished: [[HighlightSpan]](), open: [[HighlightSpan]]())) { state, line in
            let open = state.open
            let continuations = line.map { span -> (chain: [HighlightSpan], consumed: Int?) in
                let predecessors = open.indices.filter { index in
                    open[index].last.map { touches($0, span, padding: padding) } ?? false
                }
                guard predecessors.count == 1,
                      let index = predecessors.first,
                      let tail = open[index].last,
                      line.filter({ touches(tail, $0, padding: padding) }).count == 1 else {
                    return ([span], nil)
                }
                return (open[index] + [span], index)
            }
            let consumed = Set(continuations.compactMap(\.consumed))
            state.finished += open.indices.filter { !consumed.contains($0) }.map { open[$0] }
            state.open = continuations.map(\.chain)
        }
        return result.finished + result.open
    }

    /// Aligns the flush edges of a chain's spans so lines that start at the text edge share one straight side.
    /// - Parameter chain: The spans of one chain, top to bottom.
    /// - Returns: The chain with each flush leading edge moved to the chain's leftmost flush edge and each
    ///   flush trailing edge moved to its rightmost, extending dimmed ranges that touch those edges.
    static func flushAligned(_ chain: [HighlightSpan]) -> [HighlightSpan] {
        let leadingEdge = chain.filter(\.isLeadingEdgeFlush).map(\.minX).min()
        let trailingEdge = chain.filter(\.isTrailingEdgeFlush).map(\.maxX).max()
        return chain.map { span in
            var span = span
            if span.isLeadingEdgeFlush, let leadingEdge {
                if let first = span.dimmedRanges.first, first.lowerBound <= span.minX + tolerance {
                    span.dimmedRanges[0] = leadingEdge...first.upperBound
                }
                span.minX = leadingEdge
            }
            if span.isTrailingEdgeFlush, let trailingEdge {
                if let last = span.dimmedRanges.last, last.upperBound >= span.maxX - tolerance {
                    span.dimmedRanges[span.dimmedRanges.count - 1] = last.lowerBound...trailingEdge
                }
                span.maxX = trailingEdge
            }
            return span
        }
    }

    /// Returns the corners of the outline around a chain, clockwise from its top-right corner.
    /// - Parameters:
    ///   - chain: The spans of one chain, top to bottom.
    ///   - padding: The distance the outline extends past each span's leading and trailing edges,
    ///     except where the span meets a highlight of another style.
    /// - Returns: The outline's corners, without duplicate or collinear points.
    static func corners(of chain: [HighlightSpan], padding: CGFloat) -> [CGPoint] {
        let edges = zip(chain, chain.map { paddedEdges(of: $0, padding: padding) })
        let trailingSide = edges.flatMap { span, edge in
            [CGPoint(x: edge.maxX, y: span.band.lowerBound), CGPoint(x: edge.maxX, y: span.band.upperBound)]
        }
        let leadingSide = edges.reversed().flatMap { span, edge in
            [CGPoint(x: edge.minX, y: span.band.upperBound), CGPoint(x: edge.minX, y: span.band.lowerBound)]
        }
        return simplified(trailingSide + leadingSide)
    }

    private static func bridges(between chains: [[HighlightSpan]], padding: CGFloat, cornerRadius: CGFloat) -> [[CGPoint]] {
        let heads = chains.compactMap(\.first)
        return chains.compactMap(\.last).flatMap { upper in
            heads.filter { touches(upper, $0, padding: padding) }.map { lower in
                let upperEdges = paddedEdges(of: upper, padding: padding)
                let lowerEdges = paddedEdges(of: lower, padding: padding)
                let minX = max(upperEdges.minX, lowerEdges.minX)
                let maxX = min(upperEdges.maxX, lowerEdges.maxX)
                let join = upper.band.upperBound
                let top = max(upper.band.lowerBound, join - cornerRadius)
                let bottom = min(lower.band.upperBound, join + cornerRadius)
                return [
                    CGPoint(x: maxX, y: top),
                    CGPoint(x: maxX, y: bottom),
                    CGPoint(x: minX, y: bottom),
                    CGPoint(x: minX, y: top)
                ]
            }
        }
    }

    private static func dimmedArea(of chains: [[HighlightSpan]], padding: CGFloat) -> Path {
        var dimmed = Path()
        var undimmed = Path()
        for span in chains.joined() {
            let edges = paddedEdges(of: span, padding: padding)
            let height = span.band.upperBound - span.band.lowerBound
            var cursor = edges.minX
            for range in span.dimmedRanges {
                let start = range.lowerBound <= span.minX + tolerance ? edges.minX : range.lowerBound
                let end = range.upperBound >= span.maxX - tolerance ? edges.maxX : range.upperBound
                if start > cursor {
                    undimmed.addRect(CGRect(x: cursor, y: span.band.lowerBound, width: start - cursor, height: height))
                }
                dimmed.addRect(
                    CGRect(x: start, y: span.band.lowerBound, width: end - start, height: height)
                        .insetBy(dx: -dimmedAreaBleed, dy: -dimmedAreaBleed)
                )
                cursor = end
            }
            if cursor < edges.maxX {
                undimmed.addRect(CGRect(x: cursor, y: span.band.lowerBound, width: edges.maxX - cursor, height: height))
            }
        }
        return dimmed.isEmpty ? dimmed : dimmed.subtracting(undimmed)
    }

    /// Returns a closed path through the given corners, rounding each one.
    /// - Parameters:
    ///   - corners: The polygon's corners in drawing order.
    ///   - cornerRadius: The largest radius to round each corner by. A corner's radius is limited to half the
    ///     length of the shorter edge beside it, and a radius of `0` keeps the corners sharp.
    /// - Returns: The rounded path, or an empty path when there are fewer than three corners.
    static func path(of corners: [CGPoint], cornerRadius: CGFloat) -> Path {
        var path = Path()
        guard corners.count >= 3 else {
            return path
        }
        let count = corners.count
        let last = corners[count - 1]
        path.move(to: CGPoint(x: (last.x + corners[0].x) / 2, y: (last.y + corners[0].y) / 2))
        for index in corners.indices {
            let previous = corners[(index + count - 1) % count]
            let corner = corners[index]
            let next = corners[(index + 1) % count]
            let radius = min(cornerRadius, distance(previous, corner) / 2, distance(corner, next) / 2)
            if radius > 0 {
                path.addArc(tangent1End: corner, tangent2End: next, radius: radius)
            } else {
                path.addLine(to: corner)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func mergedSpans<Style: Equatable>(
        _ runs: [HighlightRun<Style>],
        band: ClosedRange<CGFloat>
    ) -> [(style: Style, span: HighlightSpan)] {
        var merged = resolvingWhitespace(runs).reduce(into: [(style: Style, span: HighlightSpan)]()) { merged, run in
            if let last = merged.last, last.style == run.style && run.minX <= last.span.maxX + tolerance {
                merged[merged.count - 1].span.maxX = max(last.span.maxX, run.maxX)
                merged[merged.count - 1].span.isTrailingEdgeFlush = last.span.isTrailingEdgeFlush || run.isTrailingEdgeFlush
                if run.isDimmed {
                    merged[merged.count - 1].span.dimmedRanges = adding(run.minX...run.maxX, to: last.span.dimmedRanges)
                }
            } else {
                merged.append((
                    run.style,
                    HighlightSpan(
                        minX: run.minX,
                        maxX: run.maxX,
                        band: band,
                        isLeadingEdgeFlush: run.isLeadingEdgeFlush,
                        isTrailingEdgeFlush: run.isTrailingEdgeFlush,
                        dimmedRanges: run.isDimmed ? [run.minX...run.maxX] : []
                    )
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

    private static func resolvingWhitespace<Style: Equatable>(_ runs: [HighlightRun<Style>]) -> [HighlightRun<Style>] {
        let groups = runs.sorted { $0.minX < $1.minX }.reduce(into: [[HighlightRun<Style>]]()) { groups, run in
            if run.isWhitespace,
               let last = groups.last?.last,
               last.isWhitespace && run.minX <= last.maxX + tolerance {
                groups[groups.count - 1].append(run)
            } else {
                groups.append([run])
            }
        }
        return groups.indices.reduce(into: []) { result, index in
            guard let first = groups[index].first, let last = groups[index].last, first.isWhitespace else {
                result += groups[index]
                return
            }
            let minX = first.minX
            let maxX = last.maxX
            let previous = result.last.flatMap { $0.maxX >= minX - tolerance ? $0 : nil }
            let next = groups.indices.contains(index + 1)
                ? groups[index + 1].first.flatMap { $0.minX <= maxX + tolerance ? $0 : nil }
                : nil
            guard let previous, let next else {
                return
            }
            if previous.style == next.style && previous.isDimmed == next.isDimmed {
                result.append(HighlightRun(style: previous.style, minX: minX, maxX: maxX, isDimmed: previous.isDimmed))
            } else {
                let middle = (minX + maxX) / 2
                result.append(HighlightRun(style: previous.style, minX: minX, maxX: middle, isDimmed: previous.isDimmed))
                result.append(HighlightRun(style: next.style, minX: middle, maxX: maxX, isDimmed: next.isDimmed))
            }
        }
    }

    private static func adding(
        _ range: ClosedRange<CGFloat>,
        to ranges: [ClosedRange<CGFloat>]
    ) -> [ClosedRange<CGFloat>] {
        guard let last = ranges.last, range.lowerBound <= last.upperBound + tolerance else {
            return ranges + [range]
        }
        return ranges.dropLast() + [last.lowerBound...max(last.upperBound, range.upperBound)]
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

    private static func simplified(_ corners: [CGPoint]) -> [CGPoint] {
        var result = corners
        var changed = true
        while changed && result.count >= 3 {
            changed = false
            for index in result.indices {
                let count = result.count
                let previous = result[(index + count - 1) % count]
                let next = result[(index + 1) % count]
                let point = result[index]
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
