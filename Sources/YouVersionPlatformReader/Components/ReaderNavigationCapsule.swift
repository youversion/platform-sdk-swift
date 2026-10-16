import SwiftUI

struct ReaderNavigationCapsule: ViewModifier {
    @Environment(BibleReaderViewModel.self) private var viewModel

    func body(content: Content) -> some View {
        content.background {
            Capsule()
                .fill(viewModel.readerButtonPrimaryColor)
                .shadow(color: viewModel.readerDropShadowColor.opacity(0.25), radius: 8, y: 3)
        }
    }
}
