import SwiftUI
import YouVersionPlatformCore

struct ReaderNavigationActionButton: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let action: BibleReaderNavigationAction
    var isMenuItem = false

    var body: some View {
        Button {
            switch action {
            case .search: viewModel.openSearch()
            }
        } label: {
            if isMenuItem {
                Label(title, systemImage: systemImage)
            } else {
                Image(systemName: systemImage)
                    .font(.title3)
                    .readerIconButton()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(actionIdentifier)
    }

    private var systemImage: String {
        switch action {
        case .search: "magnifyingglass"
        }
    }

    private var actionIdentifier: String {
        switch action {
        case .search: "searchBtn"
        }
    }

    private var title: String {
        switch action {
        case .search: String.localized("generic.search")
        }
    }
}
