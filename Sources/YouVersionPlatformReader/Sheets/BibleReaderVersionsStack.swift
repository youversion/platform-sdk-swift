import SwiftUI
import YouVersionPlatformCore

struct BibleReaderVersionsStack: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack(path: $bindableViewModel.versionsPickerStack) {
            rootView
                .navigationDestination(for: BibleReaderViewModel.VersionsPickerScreen.self) { screen in
                    destinationView(for: screen)
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if viewModel.myVersions.count > 1 {
            BibleReaderMyVersionsView()
        } else {
            ZStack {
                BibleReaderVersionListView()
                if viewModel.showFullProgressViewOverlay {
                    Color.gray.opacity(0.2)
                }
                if viewModel.showFullProgressViewOverlay {
                    ProgressView()
                }
            }

        }
    }

    @ViewBuilder
    private func destinationView(for screen: BibleReaderViewModel.VersionsPickerScreen) -> some View {
        switch screen {
        case .myVersions:
            BibleReaderMyVersionsView()
        case .moreVersions:
            BibleReaderVersionListView()
        case .versionInfo:
            BibleReaderVersionInfoView()
        case .versionDownload:
            BibleVersionDownloadView()
        case .languages:
            BibleReaderLanguagesView()
        }
    }
}

#Preview {
    BibleReaderVersionsStack()
        .environment(BibleReaderViewModel.preview)
}
