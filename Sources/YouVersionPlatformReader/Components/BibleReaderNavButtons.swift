import SwiftUI
import YouVersionPlatformCore

struct BibleReaderNavButtons: View, ReaderColors {
    @Environment(BibleReaderViewModel.self) private var viewModel

    var body: some View {
        HStack {
            Button(action: {
                viewModel.goToPreviousChapter()
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.readerCanvasPrimaryColor)
                        .shadow(color: dropShadowColor, radius: 2, x: 0, y: 2)
                        .frame(width: 42, height: 42)
                    Image(systemName: "chevron.left")
                        .foregroundStyle(viewModel.readerTextPrimaryColor)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            Spacer()
            Button(action: {
                viewModel.goToNextChapter()
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.readerCanvasPrimaryColor)
                        .shadow(color: dropShadowColor, radius: 2, x: 0, y: 2)
                        .frame(width: 42, height: 42)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(viewModel.readerTextPrimaryColor)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(viewModel.version != nil && viewModel.showChrome)
        .opacity(viewModel.version != nil ? 1 : 0.5)
        .offset(y: viewModel.showChrome ? 0 : 200)
        .animation(.easeInOut(duration: 0.3), value: viewModel.showChrome)
    }
}

#Preview {
    BibleReaderNavButtons()
        .environment(BibleReaderViewModel.preview)
}
