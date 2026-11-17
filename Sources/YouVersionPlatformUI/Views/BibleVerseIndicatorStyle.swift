import SwiftUI

/// Appearance and minimum tappable size for a customized inline verse number.
/// The background fills the number’s line-height band; expanding the tap target does not change text layout.
public struct BibleVerseIndicatorStyle: Equatable, Sendable {
    public let backgroundColor: Color
    /// Preferred number color. Dark highlights may use white to preserve contrast.
    public let foregroundColor: Color?
    public let minimumHitTargetSize: CGSize
    /// Horizontal background padding on iOS 18+. Does not add text spacing.
    public let backgroundPadding: CGFloat
    /// Reserves one nonbreaking space on each side of the number inside the colored marker.
    public let hasInlinePadding: Bool
    public let accessibilityLabel: String?

    /// Creates an indicator style. Sizes must be finite and positive.
    /// A nil accessibility label uses the displayed verse number.
    public init(backgroundColor: Color, minimumHitTargetSize: CGSize, backgroundPadding: CGFloat = 0, hasInlinePadding: Bool = false, foregroundColor: Color? = nil, accessibilityLabel: String? = nil) {
        precondition(
            minimumHitTargetSize.width.isFinite && minimumHitTargetSize.width > 0 &&
            minimumHitTargetSize.height.isFinite && minimumHitTargetSize.height > 0,
            "Verse indicator tap dimensions must be finite and positive"
        )
        precondition(backgroundPadding.isFinite && backgroundPadding >= 0, "Indicator background padding must be finite and nonnegative")
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.backgroundPadding = backgroundPadding
        self.hasInlinePadding = hasInlinePadding
        self.minimumHitTargetSize = minimumHitTargetSize
        self.accessibilityLabel = accessibilityLabel
    }
}
