import SwiftUI
import YouVersionPlatformUI

struct BibleReaderSignInView: View, ReaderColors {
    public var appName: String
    public var appMessage: String?
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 16) {
            let scale = 2.5

            Text(String.localized("signIn.introducing"))
                .font(.caption)
            Image("YouVersionPlatformLogo", bundle: .YouVersionUIBundle)
                .resizable()
                .frame(width: 238 * 2 / scale, height: 20 * 2 / scale)
                .padding(.bottom, 16)
            if let appMessage {
                Text(appMessage)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 22))
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
            Text(String(format: String.localized("signIn.paragraph"), appName))
                .padding(.bottom, 16)
            Button(action: {
                viewModel.signIn()
                viewModel.showingSignInSheet = false
            }) {
                Text(String.localized("signIn.yesButton"))
                    .padding()
                    .frame(width: 300)
            }
            .buttonStyle(
                BigButtonStyle(
                    strokeColor: borderPrimaryColor,
                    backgroundColor: buttonPrimaryColor,
                    foregroundColor: viewModel.readerTextPrimaryColor
                )
            )
            Button(action: { viewModel.showingSignInSheet = false }) {
                Text(String.localized("signIn.noButton"))
                    .padding()
                    .frame(width: 300)
            }
            .buttonStyle(
                BigButtonStyle(
                    strokeColor: borderSecondaryColor,
                    backgroundColor: buttonSecondaryColor,
                    foregroundColor: viewModel.readerTextPrimaryColor
                )
            )
        }
        .padding(.horizontal, 32)
    }

}

#Preview {
    BibleReaderSignInView(
        appName: "PreviewApp",
        appMessage: "This paragraph needs to explain why the user should sign in."
    )
    .environment(BibleReaderViewModel.preview)
}
