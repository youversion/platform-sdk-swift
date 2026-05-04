import SwiftUI
import YouVersionPlatformCore

struct BibleVersionsMyVersionsListItem: View, AbbreviationSplitting {
    @Environment(BibleVersionsViewModel.self) private var viewModel
    let version: BibleVersion

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.myVersionItemTapped(version.id)
            } label: {
                HStack(spacing: 12) {
                    // Rounded square with abbreviation
                    VStack(spacing: 0) {
                        let abbreviation = version.localizedAbbreviation ?? version.abbreviation ?? String(version.id)
                        let (letters, numbers) = splitAbbreviation(abbreviation)

                        Text(letters)
                            .font(YouVersionFonts.preferredBibleTextFont(size: 20))
                            .fontWeight(.semibold)
                            .padding(.horizontal, 4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        if !numbers.isEmpty {
                            Text(numbers)
                                .font(YouVersionFonts.preferredBibleTextFont(size: 10).weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(viewModel.readerTextPrimaryColor)
                    .frame(width: 64, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.readerButtonPrimaryColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(viewModel.readerBorderPrimaryColor, lineWidth: 1)
                            )
                    )

                    VStack(alignment: .leading) {
                        if let id = version.organizationId {
                            Text(viewModel.organizationName(id: id) ?? "")
                                .font(.caption2)
                                .foregroundStyle(viewModel.readerTextMutedColor)
                        }
                        Text(version.localizedTitle ?? version.title ?? version.localizedAbbreviation ?? version.abbreviation ?? String(version.id))
                            .font(.body)
                            .layoutPriority(1)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ellipsisMenuButton
        }
    }

    private var ellipsisMenuButton: some View {
        Menu {
            if viewModel.versionRepository.downloadStatus(for: version.id) == .downloadable {
                Button(action: {
                    viewModel.myVersionDownloadMenuTapped(version.id)
                }) {
                    HStack {
                        Text(String.localized("menu.download"))
                        Spacer()
                        Image(systemName: "arrow.down.to.line.compact")
                            .imageScale(.medium)
                    }
                }
            }
            if viewModel.versionRepository.downloadStatus(for: version.id) == .downloaded {
                Button(action: {
                    viewModel.myVersionRemoveDownloadMenuTapped(version.id)
                }) {
                    HStack {
                        Text(String.localized("menu.removeDownload"))
                        Spacer()
                        Image(systemName: "trash")
                            .imageScale(.medium)
                    }
                }
            }

            Button(action: {
                viewModel.myVersionMoreInfoMenuTapped(version.id)
            }) {
                HStack {
                    Text(String.localized("menu.moreInfo"))
                    Spacer()
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                }
            }

            if viewModel.myVersions.count > 1 {
                Button(role: .destructive, action: {
                    viewModel.myVersionRemoveVersionMenuTapped(version.id)
                }) {
                    HStack {
                        Text(String.localized("menu.removeFromList"))
                        Spacer()
                        Image(systemName: "xmark.circle")
                            .imageScale(.medium)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(viewModel.readerTextMutedColor)
                .frame(width: 32, height: 32)
                .clipShape(Rectangle())
        }
    }
}

#Preview {
    VStack {
        Divider()
        BibleVersionsMyVersionsListItem(
            version: BibleVersionsViewModel.preview.myVersions.first!
        )
        Divider()
    }
    .environment(BibleVersionsViewModel.preview)
}
