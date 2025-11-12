import SwiftUI

struct BigButtonStyle: ButtonStyle {
    let strokeColor: Color
    let backgroundColor: Color
    let foregroundColor: Color
    let strokeWidth: CGFloat = 1.5

    func makeBody(configuration: Configuration) -> some View {
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
        BigButtonStyle(
            strokeColor: .yellow,
            backgroundColor: .gray,
            foregroundColor: .black
        )
    )
}
