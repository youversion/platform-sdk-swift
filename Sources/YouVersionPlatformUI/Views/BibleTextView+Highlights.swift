import SwiftUI
import YouVersionPlatformCore

extension View {
    /// Draws Bible highlights and verse indicator backgrounds using the same line-height bands.
    /// Highlights outside the focused verse are dimmed.
    ///
    /// On iOS 17 and earlier, this returns the view unchanged.
    /// - Parameters:
    ///   - textOptions: The text options whose font size sets the highlights' padding and corner radius.
    ///   - lineSpacing: The space between lines, half of which a highlight extends above its first line and below its last.
    ///   - focusedReference: The focused verse, or `nil` to show every highlight at full strength.
    ///   - hasIndicators: Whether to collect customized verse-number backgrounds from the layout.
    func highlightLayer(textOptions: BibleTextOptions, lineSpacing: CGFloat, focusedReference: BibleReference?, hasIndicators: Bool = false) -> some View {
        modifier(BibleTextView.HighlightLayerModifier(
            textOptions: textOptions,
            lineSpacing: lineSpacing,
            focusedReference: focusedReference,
            hasIndicators: hasIndicators
        ))
    }
}

extension BibleTextView {
    struct HighlightLayerModifier: ViewModifier {
        let textOptions: BibleTextOptions
        let lineSpacing: CGFloat
        let focusedReference: BibleReference?
        let hasIndicators: Bool

        func body(content: Content) -> some View {
            if #available(iOS 18.0, *) {
                content.backgroundPreferenceValue(Text.LayoutKey.self) { layouts in
                    HighlightLayer(
                        layouts: layouts,
                        lineSpacing: lineSpacing,
                        padding: textOptions.fontSize * 0.2,
                        cornerRadius: textOptions.fontSize * 0.25,
                        dimmedHighlightOpacity: BibleTextView.dimmedTextOpacity,
                        dimProgress: focusedReference == nil ? 0 : 1,
                        hasIndicators: hasIndicators
                    )
                    .animation(BibleTextView.focusAnimation, value: focusedReference)
                }
            } else {
                content
            }
        }
    }

    @available(iOS 18.0, *)
    struct HighlightLayer: View {
        let layouts: Text.LayoutKey.Value
        let lineSpacing: CGFloat
        let padding: CGFloat
        let cornerRadius: CGFloat
        let dimmedHighlightOpacity: CGFloat
        let dimProgress: CGFloat
        let hasIndicators: Bool
        @Environment(\.layoutDirection) private var layoutDirection
        @Environment(\.displayScale) private var displayScale

        var body: some View {
            GeometryReader { proxy in
                let blocks = blocks(in: proxy)
                let highlightBlocks = blocks.map { $0.map(\.highlight) }
                let bands = HighlightOutline.bands(for: highlightBlocks, outerPadding: lineSpacing / 2)
                let highlights = HighlightOutline.paths(
                    for: highlightBlocks,
                    outerPadding: lineSpacing / 2,
                    padding: padding,
                    cornerRadius: cornerRadius,
                    lineBands: bands
                )
                let indicators = hasIndicators ? zip(blocks, bands).flatMap { block, blockBands in
                    zip(block, blockBands).flatMap { line, band in
                        line.indicators.map { indicator in
                            IndicatorBackground(indicator: indicator.indicator, bounds: CGRect(
                                x: indicator.bounds.minX - indicator.indicator.style.backgroundPadding,
                                y: band.lowerBound,
                                width: indicator.bounds.width + indicator.indicator.style.backgroundPadding * 2,
                                height: band.upperBound - band.lowerBound
                            ).insetBy(dx: 0, dy: min(1 / displayScale, (band.upperBound - band.lowerBound) / 2)))
                        }
                    }
                } : []
                let overflow = max(padding, indicators.lazy.map { $0.indicator.style.backgroundPadding }.max() ?? 0) + lineSpacing
                BackgroundCanvas(
                    highlights: highlights,
                    indicators: indicators.map { indicator in
                        (background: indicator, path: RoundedRectangle(cornerRadius: cornerRadius).path(in: indicator.bounds))
                    },
                    overflow: overflow,
                    dimmedHighlightOpacity: dimmedHighlightOpacity, dimProgress: dimProgress
                )
                .padding(-overflow)
                .preference(key: IndicatorBackgroundsKey.self, value: indicators)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }

        private struct BackgroundLine {
            let highlight: HighlightLine<Color>
            let indicators: [IndicatorBackground]
        }

        private func blocks(in proxy: GeometryProxy) -> [[BackgroundLine]] {
            layouts
                .map { anchored in
                    let origin = proxy[anchored.origin]
                    return anchored.layout.map { line in
                        let bounds = line.typographicBounds.rect.offsetBy(dx: origin.x, dy: origin.y)
                        let indicators = hasIndicators ? BibleTextView.mergedIndicatorBackgrounds(line.compactMap { run -> IndicatorBackground? in
                            guard let indicator = run[IndicatorAttribute.self] else {
                                return nil
                            }
                            return IndicatorBackground(indicator: indicator, bounds: run.typographicBounds.rect.offsetBy(dx: origin.x, dy: origin.y))
                        }) : []
                        guard line.contains(where: { $0[RenderHowAttribute.self]?.highlightColor != nil }) else {
                            return BackgroundLine(highlight: HighlightLine<Color>(bounds: bounds, runs: []), indicators: indicators)
                        }
                        let contentRects = line.lazy
                            .filter { $0[RenderHowAttribute.self]?.isIndent != true }
                            .map(\.typographicBounds.rect)
                        let contentMinX = contentRects.map(\.minX).min()
                        let contentMaxX = contentRects.map(\.maxX).max()
                        let highlight = HighlightLine(
                            bounds: bounds,
                            runs: line.compactMap { run -> HighlightRun<Color>? in
                                guard let attrs = run[RenderHowAttribute.self],
                                      let highlightColor = attrs.highlightColor else {
                                    return nil
                                }
                                let runRect = run.typographicBounds.rect
                                let isAtLineStart = layoutDirection == .rightToLeft
                                    ? contentMaxX.map { abs(runRect.maxX - $0) <= 0.5 } ?? false
                                    : contentMinX.map { abs(runRect.minX - $0) <= 0.5 } ?? false
                                return HighlightRun(
                                    style: highlightColor,
                                    minX: runRect.minX + origin.x,
                                    maxX: runRect.maxX + origin.x,
                                    isLeadingEdgeFlush: isAtLineStart && layoutDirection == .leftToRight,
                                    isTrailingEdgeFlush: isAtLineStart && layoutDirection == .rightToLeft,
                                    isWhitespace: attrs.isWhitespace,
                                    isDimmed: attrs.isDimmed
                                )
                            }
                        )
                        return BackgroundLine(highlight: highlight, indicators: indicators)
                    }
                }
                .filter { !$0.isEmpty }
                .sorted { ($0.first?.highlight.bounds.minY ?? 0) < ($1.first?.highlight.bounds.minY ?? 0) }
        }

    }

    /// Animates only painting; layout traversal, paths, and hit-target preferences stay outside the animation.
    @available(iOS 18.0, *)
    private struct BackgroundCanvas: View, Animatable {
        let highlights: [(style: Color, path: Path, dimmedArea: Path)]
        let indicators: [(background: IndicatorBackground, path: Path)]
        let overflow: CGFloat
        let dimmedHighlightOpacity: CGFloat
        var dimProgress: CGFloat

        nonisolated var animatableData: CGFloat {
            get { dimProgress }
            set { dimProgress = newValue }
        }

        var body: some View {
            let dimProgress = dimProgress
            let dimmedHighlightOpacity = dimmedHighlightOpacity
            Canvas { context, _ in
                context.translateBy(x: overflow, y: overflow)
                for highlight in highlights {
                    Self.fill(
                        highlight.path,
                        dimmedArea: highlight.dimmedArea,
                        color: highlight.style,
                        dimProgress: dimProgress,
                        dimmedHighlightOpacity: dimmedHighlightOpacity,
                        in: &context
                    )
                }
                for painted in indicators {
                    let indicator = painted.background.indicator
                    let opacity = indicator.isDimmed ? 1 - dimProgress * (1 - dimmedHighlightOpacity) : 1
                    context.fill(painted.path, with: .color(indicator.style.backgroundColor.opacity(opacity)))
                }
            }
        }

        private static func fill(
            _ path: Path,
            dimmedArea: Path,
            color: Color,
            dimProgress: CGFloat,
            dimmedHighlightOpacity: CGFloat,
            in context: inout GraphicsContext
        ) {
            guard dimProgress > 0 && !dimmedArea.isEmpty else {
                context.fill(path, with: .color(color))
                return
            }
            context.drawLayer { layer in
                layer.fill(path, with: .color(color))
                layer.blendMode = .destinationOut
                layer.opacity = dimProgress * (1 - dimmedHighlightOpacity)
                layer.fill(dimmedArea, with: .color(.black))
            }
        }
    }
}
