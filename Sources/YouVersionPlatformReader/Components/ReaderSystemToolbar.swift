import SwiftUI
import YouVersionPlatformCore

/// Chapter arrows and actions participate in the system rail; pickers use the custom bar.
struct ReaderSystemToolbar: ToolbarContent {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let layout: ReaderNavigationLayout

    var body: some ToolbarContent {
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

    private var chapterNavigationTitle: String {
        "\(String.localized("previousChapterAriaLabel")) / \(String.localized("nextChapterAriaLabel"))"
    }
}

/// Contributes items only when the host opts into system toolbar integration.
/// Native actions remain available while the custom bar is collapsed.
struct ReaderToolbarModifier: ViewModifier {
    let layout: ReaderNavigationLayout

    func body(content: Content) -> some View {
#if compiler(>=6.4) && os(iOS)
        if #available(iOS 27.1, *), layout.usesSystemToolbar {
            content.toolbar {
                ReaderSystemToolbar(layout: layout)
            }
            .toolbarMinimizationBehavior(.never, for: .navigationBar)
        } else {
            content
        }
#else
        content
#endif
    }
}
