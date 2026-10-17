import SwiftUI
import YouVersionPlatformCore

extension View {
    func highlightLayer(textOptions: BibleTextOptions, lineSpacing: CGFloat, focusedReference: BibleReference?) -> some View {
        modifier(BibleTextView.HighlightLayerModifier(
            textOptions: textOptions,
            lineSpacing: lineSpacing,
            focusedReference: focusedReference
        ))
    }
}

extension BibleTextView {
    struct HighlightLayerModifier: ViewModifier {
        let textOptions: BibleTextOptions
        let lineSpacing: CGFloat
        let focusedReference: BibleReference?

        func body(content: Content) -> some View {
            if #available(iOS 18.0, *) {
                content.backgroundPreferenceValue(Text.LayoutKey.self) { layouts in
                    HighlightLayer(
                        layouts: layouts,
                        lineSpacing: lineSpacing,
                        padding: textOptions.fontSize * 0.2,
                        cornerRadius: textOptions.fontSize * 0.25,
                        dimmedHighlightOpacity: BibleTextView.dimmedTextOpacity,
                        dimProgress: focusedReference == nil ? 0 : 1
                    )
                    .animation(BibleTextView.focusAnimation, value: focusedReference)
                }
            } else {
                content
            }
        }
    }

    @available(iOS 18.0, *)
    struct HighlightLayer: View, Animatable {
        let layouts: Text.LayoutKey.Value
        let lineSpacing: CGFloat
        let padding: CGFloat
        let cornerRadius: CGFloat
        let dimmedHighlightOpacity: CGFloat
        var dimProgress: CGFloat
        @Environment(\.layoutDirection) private var layoutDirection

        nonisolated var animatableData: CGFloat {
            get { dimProgress }
            set { dimProgress = newValue }
        }

        var body: some View {
            GeometryReader { proxy in
                let highlights = HighlightOutline.paths(
                    for: blocks(in: proxy),
                    outerPadding: lineSpacing / 2,
                    padding: padding,
                    cornerRadius: cornerRadius
                )
                let dimProgress = dimProgress
                let dimmedHighlightOpacity = dimmedHighlightOpacity
                let overflow = padding + lineSpacing
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
                }
                .padding(-overflow)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }

        private func blocks(in proxy: GeometryProxy) -> [[HighlightLine<Color>]] {
            layouts
                .map { anchored in
                    let origin = proxy[anchored.origin]
                    return anchored.layout.map { line in
                        let bounds = line.typographicBounds.rect.offsetBy(dx: origin.x, dy: origin.y)
                        guard line.contains(where: { $0[RenderHowAttribute.self]?.highlightColor != nil }) else {
                            return HighlightLine<Color>(bounds: bounds, runs: [])
                        }
                        let contentRects = line.lazy
                            .filter { $0[RenderHowAttribute.self]?.isIndent != true }
                            .map(\.typographicBounds.rect)
                        let contentMinX = contentRects.map(\.minX).min()
                        let contentMaxX = contentRects.map(\.maxX).max()
                        return HighlightLine(
                            bounds: bounds,
                            runs: line.compactMap { run -> HighlightRun<Color>? in
                                guard let attrs = run[RenderHowAttribute.self],
                                      let highlightColor = attrs.highlightColor else { return nil }
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
                    }
                }
                .filter { !$0.isEmpty }
                .sorted { ($0.first?.bounds.minY ?? 0) < ($1.first?.bounds.minY ?? 0) }
        }

        private static func fill(
            _ path: Path,
            dimmedArea: Path,
            color: Color,
            dimProgress: CGFloat,
            dimmedHighlightOpacity: CGFloat,
            in context: inout GraphicsContext
        ) {
            guard dimProgress > 0, !dimmedArea.isEmpty else {
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
