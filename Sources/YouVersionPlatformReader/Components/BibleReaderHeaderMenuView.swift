import SwiftUI
import YouVersionPlatformCore

struct BibleReaderHeaderMenuView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    var actions: [BibleReaderNavigationAction] = []

    var body: some View {
        Menu {
            ForEach(actions, id: \.self) { action in
                ReaderNavigationActionButton(action: action, isMenuItem: true)
            }
            ReaderMenuItems()
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .readerIconButton()
        }
        .accessibilityIdentifier("readerMenuBtn")
    }
}

#Preview {
    BibleReaderHeaderMenuView()
        .environment(BibleReaderViewModel.preview)
}
