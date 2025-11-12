import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderVersionInfoView: View, ReaderColors {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.openURL) private var openURL

    @State private var isVersionDownloaded: Bool?

    private let standardButtonWidth: CGFloat = 300
    private let smallButtonWidth: CGFloat = 190
    private let downloadButtonWidth: CGFloat = 90

    var body: some View {
        VStack {
            if let version = viewModel.selectedVersion {
                versionHeader
                bibleVersionButtonStack
                    .padding(.top, 16)
                VStack(alignment: .leading) {
                    if let urlstring = version.readerFooterUrl,
                       let url = URL(string: urlstring) {
                        Text(String.localized("versionInfo.detailsLabel"))
                            .font(ReaderFonts.fontHeaderS)
                            .foregroundStyle(viewModel.readerTextMutedColor)
                        HStack {
                            Image(systemName: "globe")
                            Button(action: { openURL(url) }) {
                                Text(urlstring)
                            }
                            Spacer()
                        }
                    }
                    ScrollView {
                        Text(version.copyrightLong ?? version.copyrightShort ?? "")
                            .multilineTextAlignment(.leading)
                    }
                }
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .padding(.horizontal)
            }
        }
        .navigationTitle(viewModel.selectedVersion?.localizedAbbreviation ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .customBackButton {
            viewModel.versionInfoSheetBack()
        }
        .background(viewModel.readerCanvasPrimaryColor)
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .onAppear {
            refreshDownloadStatus()
        }
        .onChange(of: viewModel.selectedVersion) {
            refreshDownloadStatus()
        }
    }

    private func refreshDownloadStatus() {
        Task {
            if let version = viewModel.selectedVersion {
                isVersionDownloaded = await BibleVersionRepository.shared.versionIsPresent(
                    for: version.id
                )
            }
        }
    }

    private var versionHeader: some View {
        VStack {
            if let version = viewModel.selectedVersion {
                Text(version.localizedAbbreviation ?? "")
                    .font(ReaderFonts.preferredBibleTextFont(size: 64))
                    .padding(.bottom, 8)
                Text(version.localizedTitle ?? "")
                    .font(ReaderFonts.fontHeaderM)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(viewModel.readerTextPrimaryColor)
                    .padding(.bottom, 4)
                Text(publisherLine(for: version))
                    .font(ReaderFonts.fontLabelM)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(viewModel.readerTextMutedColor)
            }
        }
    }

    private func publisherLine(for version: BibleVersion) -> String {
        // TEMPORARY
        let publisherName = "PUBLISHER_HERE" // version.publisher?.localName ?? ""
        let bundleSizeText = bundleSize

        if let bundleSizeText, !publisherName.isEmpty {
            return String(
                format: .localized("versionInfo.publisherWithSizeFormat"),
                publisherName,
                bundleSizeText
            )
        } else if !publisherName.isEmpty {
            return publisherName
        } else {
            return bundleSizeText ?? ""
        }
    }

    private var bundleSize: String? {
        nil
        // TODO: make a network call to determine the bundle size.
    }

    private var bibleVersionButtonStack: some View {
        VStack(spacing: 16) {
            if let version = viewModel.selectedVersion {
                let isVersionSaved = viewModel.myVersions.contains(where: { $0 == version })
                // TODO: use .isDownloadable when that exists
                let maxBuild = 0 // TEMPORARY: version.offline?.build?.max ?? 0
                let isVersionDownloadable = maxBuild > 0
                if isVersionSaved {
                    HStack {
                        if isVersionDownloadable && isVersionDownloaded == false {
                            addedButtonSmall
                            Spacer()
                            downloadButton
                        } else {
                            addedButtonLarge
                        }
                    }
                    .frame(width: standardButtonWidth)
                    readButton
                } else {
                    addButton
                    sampleButton
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: { viewModel.versionInfoSheetAdd() }) {
            Text(String.localized("versionInfo.addButton"))
                .padding()
                .frame(width: standardButtonWidth)
        }
        .buttonStyle(BigButtonStylePrimary)
    }

    private var addedButtonSmall: some View {
        addedButtonCore(width: smallButtonWidth)
    }

    private var addedButtonLarge: some View {
        addedButtonCore(width: standardButtonWidth)
    }

    private func addedButtonCore(width: CGFloat) -> some View {
        Button(action: { viewModel.versionInfoSheetAdded() }) {
            HStack {
                Image(systemName: "checkmark")
                Text(String.localized("versionInfo.addedButton"))
            }
            .padding()
            .frame(width: width)
        }
        .buttonStyle(BigButtonStylePrimary)
    }

    private var downloadButton: some View {
        Button(action: { viewModel.versionInfoSheetDownload() }) {
            Image(systemName: "arrow.down.to.line.compact")
                .padding()
                .frame(width: downloadButtonWidth)
        }
        .buttonStyle(BigButtonStyleSecondary)
    }

    private var readButton: some View {
        Button(action: { viewModel.versionInfoSheetRead() }) {
            Text(String.localized("versionInfo.readButton"))
                .padding()
                .frame(width: standardButtonWidth)
        }
        .buttonStyle(BigButtonStyleSecondary)
    }

    private var sampleButton: some View {
        Button(action: { viewModel.versionInfoSheetSample() }) {
            Text(String.localized("versionInfo.sampleButton"))
                .padding()
                .frame(width: standardButtonWidth)
        }
        .buttonStyle(BigButtonStyleSecondary)
    }

    private var BigButtonStylePrimary: some ButtonStyle {
        BigButtonStyle(
            strokeColor: .clear,
            backgroundColor: buttonContrastColor,
            foregroundColor: textInvertedColor
        )
    }

    private var BigButtonStyleSecondary: some ButtonStyle {
        BigButtonStyle(
            strokeColor: viewModel.readerTextMutedColor,
            backgroundColor: viewModel.readerCanvasPrimaryColor,
            foregroundColor: viewModel.readerTextPrimaryColor
        )
    }
}

#Preview {
    BibleReaderVersionInfoView()
        .environment(BibleReaderViewModel.preview)
}
