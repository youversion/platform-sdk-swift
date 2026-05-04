import SwiftUI
import YouVersionPlatformCore

public struct BibleVersionsStack: View {
    @Environment(BibleVersionsViewModel.self) private var viewModel

    public init() {
    }
    
    public var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack(path: $bindableViewModel.versionsPickerStack) {
            rootView
                .navigationDestination(for: BibleVersionsViewModel.VersionsPickerScreen.self) { screen in
                    destinationView(for: screen)
                }
        }
        .alert(
            viewModel.textForGenericAlertTitle,
            isPresented: $bindableViewModel.showGenericAlert
        ) {
            Button(viewModel.textForGenericAlertOKButton) { }
        } message: {
            Text(viewModel.textForGenericAlertBody)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if viewModel.myVersions.count > 1 {
            BibleVersionsMyVersionsView()
        } else {
            ZStack {
                BibleVersionsListView()
                
                if viewModel.showFullProgressViewOverlay {
                    Color.gray.opacity(0.2)
                    
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for screen: BibleVersionsViewModel.VersionsPickerScreen) -> some View {
        switch screen {
        case .myVersions:
            BibleVersionsMyVersionsView()
        case .moreVersions:
            BibleVersionsListView()
        case .versionInfo:
            BibleVersionsInfoView()
        case .versionDownload:
            BibleVersionDownloadView()
        case .languages:
            BibleVersionsLanguagesView()
        }
    }
}

#Preview {
    BibleVersionsStack()
        .environment(BibleVersionsViewModel.preview)
}
