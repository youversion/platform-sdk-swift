import SwiftUI
/// Describes how the selected-verse underline is drawn.
///
/// The SDK default is ``solid`` (a continuous gray line). Clients can
/// use ``dashed`` or create a fully custom style.
public struct VerseSelectionStyle: Sendable {
    public let color: Color
    public let strokeStyle: StrokeStyle
    public init(color: Color = .gray, strokeStyle: StrokeStyle = StrokeStyle(lineWidth: 0.5)) {
        self.color = color
        self.strokeStyle = strokeStyle
    }
    /// Solid gray underline (SDK default).
    public static let solid = VerseSelectionStyle()
    /// Dashed primar underline.
    public static let dashed = VerseSelectionStyle(color: .primary, strokeStyle: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
    /// Dotted underline
    public static let dotted = VerseSelectionStyle(color: .primary, strokeStyle: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.5, 4]))
}
