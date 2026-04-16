import SwiftUI

/// The dash pattern used for a verse-selection underline.
public enum LinePattern: Sendable {
    /// A continuous line with no gaps.
    case solid

    /// A repeating dash-gap pattern.
    ///
    /// - Parameters:
    ///   - dash: Length of each drawn segment in points.
    ///   - gap: Length of each empty segment in points.
    case dashed(dash: CGFloat = 4, gap: CGFloat = 2)

    var dashArray: [CGFloat] {
        switch self {
        case .solid:
            []
        case .dashed(let dash, let gap):
            [dash, gap]
        }
    }
}

/// Describes how the selected-verse underline is drawn.
///
/// The SDK default is ``solid`` (a continuous gray line). Clients can
/// use ``dashed`` or create a fully custom style.
public struct VerseSelectionStyle: Sendable {
    public let color: Color
    public let lineWidth: CGFloat
    public let linePattern: LinePattern

    public init(color: Color = .gray, lineWidth: CGFloat = 0.5, linePattern: LinePattern = .solid) {
        self.color = color
        self.lineWidth = lineWidth
        self.linePattern = linePattern
    }

    /// Solid gray underline (SDK default).
    public static let solid = VerseSelectionStyle()

    /// Dashed gray underline.
    public static let dashed = VerseSelectionStyle(linePattern: .dashed())
}
