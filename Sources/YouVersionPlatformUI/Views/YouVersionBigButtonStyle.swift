import SwiftUI

public struct YouVersionBigButtonStyle: ButtonStyle {
    public let strokeColor: Color
    public let backgroundColor: Color
    public let foregroundColor: Color
    public let strokeWidth: CGFloat

    public init(strokeColor: Color, backgroundColor: Color, foregroundColor: Color, strokeWidth: CGFloat = 1.5) {
        self.strokeColor = strokeColor
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.strokeWidth = strokeWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.bold)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
    }
}

#Preview {
    Button(action: { }) {
        Text("Test")
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
    .frame(width: 300)
    .buttonStyle(
        YouVersionBigButtonStyle(
            strokeColor: .yellow,
            backgroundColor: .gray,
            foregroundColor: .black
        )
    )
}
