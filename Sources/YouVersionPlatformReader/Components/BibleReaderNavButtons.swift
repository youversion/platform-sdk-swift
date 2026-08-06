import SwiftUI
import YouVersionPlatformCore

struct BibleReaderNavButtons: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            Button(action: viewModel.goToPreviousChapter) {
                ZStack {
                    Circle()
                        .fill(viewModel.readerCanvasPrimaryColor)
                        .shadow(color: viewModel.readerDropShadowColor, radius: 2, x: 0, y: 2)
                        .frame(width: 42, height: 42)
                    Image(systemName: "chevron.left")
                        .foregroundStyle(viewModel.readerTextPrimaryColor)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            Spacer()
            Button(action: viewModel.goToNextChapter) {
                ZStack {
                    Circle()
                        .fill(viewModel.readerCanvasPrimaryColor)
                        .shadow(color: viewModel.readerDropShadowColor, radius: 2, x: 0, y: 2)
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
        .opacity(opacityForVisibility)
        .offset(y: offsetForVisibility)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewModel.showChrome)
    }

    private var opacityForVisibility: Double {
        let baseOpacity = viewModel.version != nil ? 1.0 : 0.5
        if reduceMotion {
            return viewModel.showChrome ? baseOpacity : 0
        }
        return baseOpacity
    }

    private var offsetForVisibility: CGFloat {
        if reduceMotion {
            return 0
        }
        return viewModel.showChrome ? 0 : 200
    }
}

#Preview {
    BibleReaderNavButtons()
        .environment(BibleReaderViewModel.preview)
}
