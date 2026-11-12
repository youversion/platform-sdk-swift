import SwiftUI
import YouVersionPlatformCore

extension BibleTextView {
    static let indicatorLinkScheme = "verse-indicator"

    struct IndicatorID: Hashable {
        let blockID: UUID
        let runIndex: Int
    }

    struct IndicatorAttribute: TextAttribute {
        let id: IndicatorID
        let reference: BibleReference
        let style: BibleVerseIndicatorStyle
        let isDimmed: Bool

        /// Hashes the marker identity and its appearance and interaction configuration.
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(reference)
            hasher.combine(style.backgroundColor)
            hasher.combine(style.foregroundColor)
            hasher.combine(style.backgroundPadding)
            hasher.combine(style.hasInlinePadding)
            hasher.combine(style.minimumHitTargetSize.width)
            hasher.combine(style.minimumHitTargetSize.height)
            hasher.combine(style.accessibilityLabel)
            hasher.combine(isDimmed)
        }
    }

    struct IndicatorBackground: Equatable {
        let indicator: IndicatorAttribute
        let bounds: CGRect
    }

    /// Combines bidi and font-fallback runs of one marker before painting or expanding its tap target.
    static func mergedIndicatorBackgrounds(_ backgrounds: [IndicatorBackground]) -> [IndicatorBackground] {
        let markers = backgrounds.reduce(into: [IndicatorID: IndicatorBackground]()) { markers, background in
            let indicator = background.indicator
            let bounds = markers[indicator.id]?.bounds.union(background.bounds) ?? background.bounds
            markers[indicator.id] = IndicatorBackground(indicator: indicator, bounds: bounds)
        }
        return markers.values.sorted { lhs, rhs in
            let left = lhs.indicator
            let right = rhs.indicator
            return left.reference == right.reference ? left.id.runIndex < right.id.runIndex : left.reference < right.reference
        }
    }

    struct IndicatorBackgroundsKey: PreferenceKey {
        static var defaultValue: [IndicatorBackground] { [] }

        static func reduce(value: inout [IndicatorBackground], nextValue: () -> [IndicatorBackground]) {
            value += nextValue()
        }
    }

    struct IndicatorHitTargets: ViewModifier {
        let onSelected: ((BibleReference) -> Void)?

        func body(content: Content) -> some View {
            if #available(iOS 18.0, *), let onSelected {
                content.overlayPreferenceValue(IndicatorBackgroundsKey.self) { backgrounds in
                    HitTargets(backgrounds: backgrounds, onSelected: onSelected)
                }
            } else {
                content
            }
        }
    }
}

/// Uses physical layout coordinates so SwiftUI does not mirror absolute positions a second time in RTL text.
@available(iOS 18.0, *)
private struct HitTargets: View {
    let backgrounds: [BibleTextView.IndicatorBackground]
    let onSelected: (BibleReference) -> Void

    var body: some View {
        GeometryReader { _ in
            ForEach(targets) { target in
                Button { onSelected(target.reference) } label: {
                    Color.clear
                        .frame(width: target.bounds.width, height: target.bounds.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: target.bounds.midX, y: target.bounds.midY)
                .accessibilityLabel(target.label)
                .accessibilityIdentifier("verse-indicator-\(target.reference.versionId)-\(target.reference.passageId)")
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var targets: [Target] {
        BibleTextView.mergedIndicatorBackgrounds(backgrounds).map { marker in
            let width = max(marker.bounds.width, marker.indicator.style.minimumHitTargetSize.width)
            let height = max(marker.bounds.height, marker.indicator.style.minimumHitTargetSize.height)
            return Target(indicator: marker.indicator, bounds: CGRect(
                x: marker.bounds.midX - width / 2, y: marker.bounds.midY - height / 2,
                width: width, height: height
            ))
        }
    }
}

private struct Target: Identifiable {
    let indicator: BibleTextView.IndicatorAttribute
    let bounds: CGRect
    var id: BibleTextView.IndicatorID { indicator.id }
    var reference: BibleReference { indicator.reference }
    var label: String {
        indicator.style.accessibilityLabel ?? reference.verseStart.map(String.init) ?? reference.passageId
    }
}
