import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

public struct BibleReaderMyVersionsView: View, ReaderColors {
    @Environment(BibleReaderViewModel.self) private var viewModel

    public var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sortedMyVersions, id: \.id) { v in
                        BibleReaderMyVersionsListItem(item: v)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 16)
            }
            Button(String.localized("button.moreVersions")) {
                handleMoreVersions()
            }
            .font(.system(size: 14))
            .fontWeight(.bold)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(buttonPrimaryColor)
            )
            .padding(.bottom, 8)
            Text(viewModel.bibleVersionStatisticsPromo)
                .font(.caption)
            Spacer()
        }
        .navigationTitle(String.localized("myVersions.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    handleMoreVersions()
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .background(viewModel.readerCanvasPrimaryColor)
    }

    private var sortedMyVersions: [BibleVersion] {
        viewModel.myVersions.sorted { a, b in
            a.localizedTitle ?? "" < b.localizedTitle ?? ""
        }
    }

    private func handleMoreVersions() {
        viewModel.versionsStackPush(to: .moreVersions)
    }

}

#Preview {
    BibleReaderMyVersionsView()
        .environment(BibleReaderViewModel.preview)
}
