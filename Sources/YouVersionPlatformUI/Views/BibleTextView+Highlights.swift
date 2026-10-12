import SwiftUI

extension BibleTextView {
    struct HighlightStyle: Equatable {
        let color: Color
        let isDimmed: Bool
    }

    @ViewBuilder
    func withHighlights(_ content: some View, textOptions: BibleTextOptions) -> some View {
        if #available(iOS 18.0, *) {
            content.backgroundPreferenceValue(Text.LayoutKey.self) { layouts in
                HighlightLayer(
                    layouts: layouts,
                    lineSpacing: fontRelativeLineSpacing(textOptions: textOptions),
                    padding: textOptions.fontSize * 0.2,
                    cornerRadius: textOptions.fontSize * 0.25,
                    dimmedHighlightOpacity: Self.dimmedTextOpacity,
                    dimProgress: focusedReference == nil ? 0 : 1
                )
                .animation(Self.focusAnimation, value: focusedReference)
            }
        } else {
            content
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
                            style: highlight.style,
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

        private func blocks(in proxy: GeometryProxy) -> [[HighlightLine<HighlightStyle>]] {
            layouts
                .map { anchored in
                    let origin = proxy[anchored.origin]
                    return anchored.layout.map { line in
                        let contentMinX = line
                            .filter { $0[RenderHowAttribute.self]?.isIndent != true }
                            .map { $0.typographicBounds.rect.minX }
                            .min()
                        return HighlightLine(
                            bounds: line.typographicBounds.rect.offsetBy(dx: origin.x, dy: origin.y),
                            runs: line.compactMap { run -> HighlightRun<HighlightStyle>? in
                                guard let attrs = run[RenderHowAttribute.self],
                                      let highlightColor = attrs.highlightColor else { return nil }
                                let runRect = run.typographicBounds.rect
                                let isAtLineStart = contentMinX.map { abs(runRect.minX - $0) <= 0.5 } ?? false
                                return HighlightRun(
                                    style: HighlightStyle(color: highlightColor, isDimmed: attrs.isDimmed),
                                    minX: runRect.minX + origin.x,
                                    maxX: runRect.maxX + origin.x,
                                    isAtLineStart: isAtLineStart,
                                    isWhitespace: attrs.isWhitespace
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
            style: HighlightStyle,
            dimProgress: CGFloat,
            dimmedHighlightOpacity: CGFloat,
            in context: inout GraphicsContext
        ) {
            if style.isDimmed && dimProgress > 0 {
                if dimProgress < 1 {
                    var fullColorContext = context
                    fullColorContext.opacity = 1 - dimProgress
                    fullColorContext.fill(path, with: .color(style.color))
                }
                context.drawLayer { layer in
                    layer.opacity = dimProgress
                    layer.fill(path, with: .color(style.color.opacity(dimmedHighlightOpacity)))
                }
            } else {
                context.fill(path, with: .color(style.color))
            }
        }
    }
}
