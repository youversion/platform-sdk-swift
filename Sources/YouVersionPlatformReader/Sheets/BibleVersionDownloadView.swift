import SwiftUI
import YouVersionPlatformCore

struct BibleVersionDownloadView: View, ReaderColors {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var viewModel = viewModel // to enable $viewModel.foo

        VStack {
            if let version = viewModel.selectedVersion {
                Text(version.localizedAbbreviation ?? "")
                    .font(ReaderFonts.preferredBibleTextFont(size: 64))
                Text(version.localizedTitle ?? "")
                    .font(ReaderFonts.fontHeaderS)

                HStack {
                    Text(String.localized("download.agreementParagraph"))
                        .padding()
                        .font(ReaderFonts.fontCaptionsL)
                    Button(action: {
                        viewModel.versionDownloadInfoButtonTapped(for: version)
                    }) {
                        Image(systemName: "info.circle")
                            .padding(.trailing)
                    }
                }
                .padding(.horizontal, 32)

                Text(String.localized("download.callToAction"))
                    .font(ReaderFonts.fontHeaderS)

                Button(action: {
                    viewModel.versionDownloadViewAccepted(for: version)
                }) {
                    Text(String.localized("download.agreeButton"))
                        .padding()
                        .frame(width: 300)
                }
                .buttonStyle(
                    BigButtonStyle(
                        strokeColor: .clear,
                        backgroundColor: buttonContrastColor,
                        foregroundColor: textInvertedColor
                    )
                )
                .padding()
                
                Button(action: {
                    viewModel.versionDownloadViewDismissed(for: version)
                }) {
                    Text(String.localized("download.disagreeButton"))
                        .padding()
                        .frame(width: 300)
                }
                .buttonStyle(
                    BigButtonStyle(
                        strokeColor: .clear,
                        backgroundColor: buttonSecondaryColor,
                        foregroundColor: viewModel.readerTextPrimaryColor
                    )
                )
                
                Spacer()
            }
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .alert(
            String.localized("versionInfo.sharingTitle"),
            isPresented: $viewModel.showVersionInfoSharingAlert
        ) {
            Button(String.localized("versionInfo.sharingPrivacyButton")) {
                viewModel.showVersionInfoSharingAlert = false
                openURL(URL(string: "https://bible.com/privacy")!)
            }
            Button(String.localized("versionInfo.sharingOKButton")) {
                viewModel.showVersionInfoSharingAlert = false
            }
        } message: {
            Text(viewModel.showVersionInfoSharingText)
        }

    }
}

#Preview {
    BibleVersionDownloadView()
        .environment(BibleReaderViewModel.preview)
}
