import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// Custom navigation in ordinary windows; its contents do not depend on a width breakpoint.
struct ReaderNavigationBar: View {
    private static let leadingPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 8
    static let actionRowHeight: CGFloat = 44 + 2 * verticalPadding
    // Visual spacing below the floating iPad tab row, verified in simulator captures.
    static let topTabRowBottomSpacing: CGFloat = 12

    @Environment(BibleReaderViewModel.self) private var viewModel
    let layout: ReaderNavigationLayout
    let isUpperBar: Bool
    let width: CGFloat

    @ScaledMetric(relativeTo: .subheadline) private var preferredPickerWidth = 392
    var cornerInsets = EdgeInsets()

    var body: some View {
        Group {
            if isUpperBar {
                upperBar
            } else {
                HStack(spacing: 8) {
                    if viewModel.showChrome, let action = layout.primaryAction {
                        ReaderNavigationActionButton(action: action)
                            .modifier(ReaderNavigationCapsule())
                    }
                    ReaderNavigationPickers(
                        width: min(width, 600) - 24 - (layout.primaryAction == nil ? 0 : 52),
                        includesArrows: true, usesNativeBackground: false
                    )
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Self.verticalPadding)
        .background {
            if isUpperBar {
                viewModel.readerCanvasPrimaryColor
            } else {
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: viewModel.readerCanvasPrimaryColor.opacity(0), location: 0),
                        Gradient.Stop(color: viewModel.readerCanvasPrimaryColor, location: 0.5),
                        Gradient.Stop(color: viewModel.readerCanvasPrimaryColor, location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
    }

    private var upperBar: some View {
        let columnLeading = max(0, (width - viewModel.readerMaxWidth - 2 * viewModel.readerHorizontalPadding) / 2)
        let leading = max(columnLeading + Self.leadingPadding, cornerInsets.leading)
        let trailing = max(12, cornerInsets.trailing)
        let actionsWidth: CGFloat = layout.upperAction == nil ? 44 : 96
        return Group {
            if layout.placement == .bottomBar {
                upperActions.frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, leading)
                    .padding(.trailing, trailing)
            } else {
                HStack(spacing: 8) {
                    ReaderNavigationPickers(
                        width: min(preferredPickerWidth, max(0, width - leading - trailing - actionsWidth - 8)),
                        includesArrows: true, usesNativeBackground: false,
                        fillsAvailableWidth: true
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    upperActions
                }
                .padding(.leading, leading)
                .padding(.trailing, trailing)
            }
        }
    }

    private var upperActions: some View {
        HStack(spacing: 8) {
            if let action = layout.upperAction {
                ReaderNavigationActionButton(action: action)
            }
            BibleReaderHeaderMenuView(actions: layout.menuActions)
        }
        .opacity(viewModel.showChrome ? 1 : 0)
        .allowsHitTesting(viewModel.showChrome)
        .accessibilityHidden(!viewModel.showChrome)
    }

}

struct ReaderNavigationCapsule: ViewModifier {
    @Environment(BibleReaderViewModel.self) private var viewModel
    var isEnabled = true

    func body(content: Content) -> some View {
        content.background {
            if isEnabled {
                Capsule()
                    .fill(viewModel.readerButtonPrimaryColor)
                    .shadow(color: viewModel.readerDropShadowColor.opacity(0.25), radius: 8, y: 3)
            }
        }
    }
}
