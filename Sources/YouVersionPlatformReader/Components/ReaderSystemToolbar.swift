import SwiftUI
import YouVersionPlatformCore

/// Native items participate in the system rail; the horizontal pickers remain one item.
struct ReaderSystemToolbar: ToolbarContent {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let layout: ReaderNavigationLayout
    let width: CGFloat

    var body: some ToolbarContent {
        ToolbarItem(placement: pickerPlacement) {
            HStack(spacing: 8) {
                if viewModel.showChrome, let action = layout.primaryAction {
                    ReaderNavigationActionButton(action: action)
                }
                ReaderNavigationPickers(width: max(0, min(width - 100, 380)), includesArrows: false, usesNativeBackground: true)
            }
            .buttonStyle(.plain)
        }
        if viewModel.showChrome {
            ToolbarItemGroup(placement: .primaryAction) {
                ControlGroup {
                    Button(action: viewModel.goToPreviousChapter) {
                        Label(String.localized("previousChapterAriaLabel"), systemImage: "chevron.backward")
                    }
                    .accessibilityIdentifier("previousChapterBtn")
                    Button(action: viewModel.goToNextChapter) {
                        Label(String.localized("nextChapterAriaLabel"), systemImage: "chevron.forward")
                    }
                    .accessibilityIdentifier("nextChapterBtn")
                } label: {
                    Label(chapterNavigationTitle, systemImage: "arrow.left.arrow.right")
                }
                .disabled(viewModel.version == nil)
                if let action = layout.upperAction {
                    ReaderNavigationActionButton(action: action, isMenuItem: true)
                }
                BibleReaderHeaderMenuView(actions: layout.menuActions)
            }
        }
    }

    private var chapterNavigationTitle: String {
        "\(String.localized("previousChapterAriaLabel")) / \(String.localized("nextChapterAriaLabel"))"
    }

    private var pickerPlacement: ToolbarItemPlacement {
#if os(iOS)
        layout.placement == .topBar ? .topBarLeading : .bottomBar
#else
        .automatic
#endif
    }
}

/// Contributes items only when the host opts into system toolbar integration.
struct ReaderToolbarModifier: ViewModifier {
    let layout: ReaderNavigationLayout
    let width: CGFloat

    func body(content: Content) -> some View {
        if layout.usesSystemToolbar {
            content.toolbar {
                ReaderSystemToolbar(layout: layout, width: width)
            }
        } else {
            content
        }
    }
}
