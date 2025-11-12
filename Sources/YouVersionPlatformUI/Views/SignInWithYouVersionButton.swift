import SwiftUI

public struct SignInWithYouVersionButton: View {
    
    public enum Mode: String, CaseIterable {
        case full
        case compact
        case iconOnly
    }

    public enum ButtonShape {
        case capsule
        case rectangle
    }
    
    @Environment(\.colorScheme) var colorScheme
    private let shape: ButtonShape
    private let mode: Mode
    private let isStroked: Bool
    private let verticalPadding = CGFloat(12)
    private let horizontalPadding = CGFloat(20)
    private let onTap: () -> Void
    @ScaledMetric(relativeTo: .body) private var iconEdge: CGFloat = 24
    
    public init(shape: ButtonShape = .capsule,
                mode: Mode = .full,
                isStroked: Bool = true,
                onTap: @escaping () -> Void) {
        self.shape = shape
        self.mode = mode
        self.isStroked = isStroked
        self.onTap = onTap
    }
    
    private var strokeColor: Color {
        let colorGray25 = Color(red: 0x82 / 255.0, green: 0x80 / 255.0, blue: 0x80 / 255.0)
        let colorGray35 = Color(red: 0x47 / 255.0, green: 0x45 / 255.0, blue: 0x45 / 255.0)
        return colorScheme == .dark ? colorGray35 : colorGray25
    }
    
    private var bibleAppLogo: some View {
        Image("BibleAppLogo@4x", bundle: .YouVersionUIBundle)
            .resizable()
            .frame(width: iconEdge, height: iconEdge)
    }
    
    private var localizedLoginText: Text {
        let formatString = String.localized("signIn.button.full")
        let brandName = "YouVersion"
        let fullText = String(format: formatString, brandName)

        var attributed = AttributedString(fullText)
        if let range = attributed.range(of: brandName) {
            attributed[range].font = .body.bold()
        }

        return Text(attributed)
    }
    
    private var strokeWidth: CGFloat {
        isStroked ? 1.5 : 0
    }

    private var accessibilityLabel: Text {
        switch mode {
        case .iconOnly, .full:
            Text(String.localized("signIn.button.accessibility"))
        case .compact:
            Text(String.localized("signIn.button.compact"))
        }
    }

    @ViewBuilder
    private var buttonContent: some View {
        switch mode {
        case .iconOnly:
            bibleAppLogo
                .padding(verticalPadding)
        case .full:
            HStack(spacing: 0) {
                bibleAppLogo
                    .padding(.trailing, 8)
                localizedLoginText
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
        case .compact:
            HStack(spacing: 0) {
                bibleAppLogo
                    .padding(.trailing, 8)
                Text(String.localized("signIn.button.compact"))
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
        }
    }
    
    public var body: some View {
        Button(action: onTap) {
            buttonContent
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(.isButton)
        }
        .buttonStyle(
            SignInWithYouVersionButtonStyle(
                shape: shape,
                strokeColor: strokeColor,
                strokeWidth: strokeWidth,
                colorScheme: colorScheme
            )
        )
    }
}

private struct SignInWithYouVersionButtonStyle: ButtonStyle {
    let shape: SignInWithYouVersionButton.ButtonShape
    let strokeColor: Color
    let strokeWidth: CGFloat
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        let content = configuration.label
            .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .opacity(configuration.isPressed ? 0.8 : 1.0)

        if shape == .capsule {
            content
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
        } else {
            content
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
        }
    }
}

#if DEBUG
#Preview {
    buttonGrid
        .padding()
        .background(Color.green)
}

@MainActor
private var buttonGrid: some View {
    VStack {
        SignInWithYouVersionButton(mode: .full, isStroked: true, onTap: {})
        SignInWithYouVersionButton(mode: .full, isStroked: false, onTap: {})
        HStack {
            SignInWithYouVersionButton(mode: .compact, isStroked: true, onTap: {})
            SignInWithYouVersionButton(mode: .compact, isStroked: false, onTap: {})
        }
        SignInWithYouVersionButton(shape: .rectangle, mode: .full, isStroked: true, onTap: {})
        SignInWithYouVersionButton(shape: .rectangle, mode: .full, isStroked: false, onTap: {})
        HStack {
            SignInWithYouVersionButton(shape: .rectangle, mode: .compact, isStroked: true, onTap: {})
            SignInWithYouVersionButton(shape: .rectangle, mode: .compact, isStroked: false, onTap: {})
        }
        HStack {
            SignInWithYouVersionButton(shape: .rectangle, mode: .iconOnly, isStroked: true, onTap: {})
            SignInWithYouVersionButton(shape: .rectangle, mode: .iconOnly, isStroked: false, onTap: {})
        }
    }
}
#endif
