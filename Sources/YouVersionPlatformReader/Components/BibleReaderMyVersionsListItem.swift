import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderMyVersionsListItem: View, ReaderColors, AbbreviationSplitting {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let item: BibleVersion

    var body: some View {
        HStack(spacing: 12) {
            // Rounded square with abbreviation
            VStack(spacing: 0) {
                let abbreviation = item.localizedAbbreviation ?? item.abbreviation ?? String(item.id)
                let (letters, numbers) = splitAbbreviation(abbreviation)

                Text(letters)
                    .font(ReaderFonts.preferredBibleTextFont(size: 20))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if !numbers.isEmpty {
                    Text(numbers)
                        .font(ReaderFonts.preferredBibleTextFont(size: 10).weight(.semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(viewModel.readerTextPrimaryColor)
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(buttonPrimaryColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(borderPrimaryColor, lineWidth: 1)
                    )
            )
            .onTapGesture {
                viewModel.myVersionItemTapped(item.id)
            }

            VStack(alignment: .leading) {
                if let id = item.organizationId {
                    Text(viewModel.organizationName(id: id) ?? "")
                        .font(.caption2)
                        .foregroundStyle(viewModel.readerTextMutedColor)
                }
                Text(item.localizedTitle ?? item.localizedAbbreviation ?? String(item.id))
                    .font(.body)
                    .layoutPriority(1)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .onTapGesture {
                viewModel.myVersionItemTapped(item.id)
            }

            Spacer()
            if viewModel.versionRepository.downloadStatus(for: item.id) != .downloaded {
                Image(systemName: "cloud")
                    .foregroundStyle(viewModel.readerTextMutedColor)
                    .padding(.trailing, 8)
            }
            ellipsisMenuButton
        }
        .contentShape(Rectangle())
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
        BibleReaderMyVersionsListItem(
            item: BibleReaderViewModel.preview.myVersions.first!
        )
        Divider()
    }
    .environment(BibleReaderViewModel.preview)
}
