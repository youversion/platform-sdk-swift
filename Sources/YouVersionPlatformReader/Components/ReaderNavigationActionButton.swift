import SwiftUI
import YouVersionPlatformCore

struct ReaderNavigationActionButton: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let action: BibleReaderNavigationAction
    var isMenuItem = false

    var body: some View {
        Group {
            if isMenuItem {
                actionButton
            } else {
                actionButton.buttonStyle(.plain)
            }
        }
        .accessibilityLabel(title)
        .accessibilityIdentifier(actionIdentifier)
    }

    private var actionButton: some View {
        Button {
            switch action {
            case .search: viewModel.openSearch()
            }
        } label: {
            if isMenuItem {
                Label {
                    Text(title)
                } icon: {
                    actionImage
                }
            } else {
                ReaderNavigationActionIcon(image: actionImage)
                    .readerIconButton()
            }
        }
    }

    private var actionImage: Image {
        switch action {
        case .search: Image.magnifyingGlass
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

private struct ReaderNavigationActionIcon: View {
    let image: Image
    @ScaledMetric(relativeTo: .title3) private var size = 24

    var body: some View {
        image
            .resizable()
            .frame(width: size, height: size)
    }
}
