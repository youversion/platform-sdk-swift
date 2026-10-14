import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// Provides the custom picker and action-button content for a reader navigation bar.
/// ReaderContent positions the bar above or below the reading area.
struct ReaderNavigationBar: View {
    private static let bottomBarMaximumWidth: CGFloat = 600
    private static let leadingPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 8
    static let actionRowHeight: CGFloat = 44 + 2 * verticalPadding
    // Assumed gap between the floating iPad tab row and the bottom of the top safe area,
    // calibrated from simulator captures rather than a documented system metric.
    // Subtracting this gap and our action-row height from the top safe-area inset aligns
    // Search/Menu beside the tabs. This assumes that inset represents the system tab area
    // without additional host headers or banners; those or changed system metrics can shift alignment.
    static let assumedTopTabRowBottomSpacing: CGFloat = 12

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
                lowerBar
            }
        }
        .padding(.vertical, viewModel.showChrome ? Self.verticalPadding : 0)
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
        let columnLeading = max(0, (width - BibleReaderView.contentMaximumWidth - 2 * BibleReaderView.contentHorizontalPadding) / 2)
        let leading = max(columnLeading + Self.leadingPadding, cornerInsets.leading)
        let trailing = max(12, cornerInsets.trailing)
        let actionsWidth: CGFloat = layout.usesSystemToolbar ? 0 : (layout.upperAction == nil ? 44 : 96)
        return Group {
            if layout.placement == .bottomBar {
                upperActions
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, leading)
                    .padding(.trailing, trailing)
            } else {
                HStack(spacing: 8) {
                    ReaderNavigationPickers(
                        width: min(preferredPickerWidth, max(0, width - leading - trailing - actionsWidth - 8)),
                        includesArrows: !layout.usesSystemToolbar,
                        fillsAvailableWidth: true,
                        compactAlignment: .leading,
                        compactLeadingPadding: max(0, columnLeading + BibleReaderView.contentHorizontalPadding - leading)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !layout.usesSystemToolbar {
                        upperActions
                    }
                }
                .padding(.leading, leading)
                .padding(.trailing, trailing)
            }
        }
    }

    private var lowerBar: some View {
        HStack(spacing: 8) {
            if viewModel.showChrome, let action = layout.primaryAction {
                ReaderNavigationActionButton(action: action)
                    .modifier(ReaderNavigationCapsule())
            }
            ReaderNavigationPickers(
                width: min(width, Self.bottomBarMaximumWidth) - 24 - (layout.primaryAction == nil ? 0 : 52),
                includesArrows: !layout.usesSystemToolbar
            )
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: Self.bottomBarMaximumWidth)
        .frame(maxWidth: .infinity)
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
