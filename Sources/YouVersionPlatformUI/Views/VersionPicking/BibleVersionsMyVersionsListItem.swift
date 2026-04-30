import SwiftUI
import YouVersionPlatformCore

struct BibleVersionsMyVersionsListItem: View, AbbreviationSplitting {
    @Environment(BibleVersionsViewModel.self) private var viewModel
    let item: BibleVersion

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.myVersionItemTapped(item.id)
            } label: {
                HStack(spacing: 12) {
                    // Rounded square with abbreviation
                    VStack(spacing: 0) {
                        let abbreviation = item.localizedAbbreviation ?? item.abbreviation ?? String(item.id)
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
                        if let id = item.organizationId {
                            Text(viewModel.organizationName(id: id) ?? "")
                                .font(.caption2)
                                .foregroundStyle(viewModel.readerTextMutedColor)
                        }
                        Text(item.localizedTitle ?? item.title ?? item.localizedAbbreviation ?? item.abbreviation ?? String(item.id))
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
            if viewModel.versionRepository.downloadStatus(for: item.id) == .downloadable {
                Button(action: {
                    viewModel.myVersionDownloadMenuTapped(item.id)
                }) {
                    HStack {
                        Text(String.localized("menu.download"))
                        Spacer()
                        Image(systemName: "arrow.down.to.line.compact")
                            .imageScale(.medium)
                    }
                }
            }
            if viewModel.versionRepository.downloadStatus(for: item.id) == .downloaded {
                Button(action: {
                    viewModel.myVersionRemoveDownloadMenuTapped(item.id)
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
                viewModel.myVersionMoreInfoMenuTapped(item.id)
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
                    viewModel.myVersionRemoveVersionMenuTapped(item.id)
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
            item: BibleVersionsViewModel.preview.myVersions.first!
        )
        Divider()
    }
    .environment(BibleVersionsViewModel.preview)
}
