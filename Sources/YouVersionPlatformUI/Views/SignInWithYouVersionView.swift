import SwiftUI
import YouVersionPlatformCore

/// A reusable sign-in prompt view. Reads ``YouVersionPlatformConfiguration/appName``
/// and ``YouVersionPlatformConfiguration/signInPromptMessage`` from the global configuration.
///
/// The caller provides action closures and theming colors so the view has
/// no dependency on any specific view model.
public struct SignInWithYouVersionView: View {
    private let onSignIn: () -> Void
    private let onDismiss: () -> Void

    private let borderPrimaryColor: Color
    private let buttonPrimaryColor: Color
    private let borderSecondaryColor: Color
    private let buttonSecondaryColor: Color
    private let textPrimaryColor: Color

    /// Creates a sign-in prompt view.
    ///
    /// - Parameters:
    ///   - textPrimaryColor: Primary text and button label color.
    ///   - borderPrimaryColor: Stroke color for the primary (sign-in) button.
    ///   - buttonPrimaryColor: Background color for the primary button.
    ///   - borderSecondaryColor: Stroke color for the secondary (dismiss) button.
    ///   - buttonSecondaryColor: Background color for the secondary button.
    ///   - onSignIn: Called when the user taps the sign-in button.
    ///   - onDismiss: Called when the user declines or dismisses the sheet.
    public init(
        textPrimaryColor: Color = .primary,
        borderPrimaryColor: Color = .primary,
        buttonPrimaryColor: Color = .clear,
        borderSecondaryColor: Color = .secondary,
        buttonSecondaryColor: Color = .clear,
        onSignIn: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.textPrimaryColor = textPrimaryColor
        self.borderPrimaryColor = borderPrimaryColor
        self.buttonPrimaryColor = buttonPrimaryColor
        self.borderSecondaryColor = borderSecondaryColor
        self.buttonSecondaryColor = buttonSecondaryColor
        self.onSignIn = onSignIn
        self.onDismiss = onDismiss
    }

    private var appName: String {
        YouVersionPlatformConfiguration.appName ?? ""
    }

    private var signInMessage: String? {
        YouVersionPlatformConfiguration.signInPromptMessage
    }

    public var body: some View {
        VStack(spacing: 16) {
            let scale = 2.5

            Text(String.localized("signIn.introducing"))
                .font(.caption)
            Image("YouVersionPlatformLogo", bundle: .YouVersionUIBundle)
                .resizable()
                .frame(width: 238 * 2 / scale, height: 20 * 2 / scale)
                .padding(.bottom, 16)
            if let signInMessage {
                Text(signInMessage)
                    .multilineTextAlignment(.center)
                    .font(.title3)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
            Text(String(format: String.localized("signIn.paragraph"), appName))
                .padding(.bottom, 16)
            Button(action: onSignIn) {
                Text(String.localized("signIn.yesButton"))
                    .padding()
                    .frame(width: 300)
            }
            .buttonStyle(
                YouVersionBigButtonStyle(
                    strokeColor: borderPrimaryColor,
                    backgroundColor: buttonPrimaryColor,
                    foregroundColor: textPrimaryColor
                )
            )
            Button(action: onDismiss) {
                Text(String.localized("signIn.noButton"))
                    .padding()
                    .frame(width: 300)
            }
            .buttonStyle(
                YouVersionBigButtonStyle(
                    strokeColor: borderSecondaryColor,
                    backgroundColor: buttonSecondaryColor,
                    foregroundColor: textPrimaryColor
                )
            )
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    SignInWithYouVersionView(
        onSignIn: { print("sign in") },
        onDismiss: { print("dismiss") }
    )
}
