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
    /// Dashed gray underline.
    public static let dashed = VerseSelectionStyle(strokeStyle: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
}
