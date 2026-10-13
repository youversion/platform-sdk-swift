import SwiftUI
import YouVersionPlatformCore

/// Native items participate in the system rail; the horizontal pickers remain one item.
struct ReaderDuoToolbar: ToolbarContent {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let layout: ReaderNavigationLayout
    let width: CGFloat

    var body: some ToolbarContent {
        ToolbarItem(placement: pickerPlacement) {
            HStack(spacing: 8) {
                if let action = layout.primaryAction {
                    ReaderNavigationActionButton(action: action)
                }
                ReaderNavigationPickers(width: min(width - 100, 380), includesArrows: false, usesNativeBackground: true)
            }
            .buttonStyle(.plain)
        }
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
            ReaderNavigationMenu(actions: layout.menuActions)
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

struct ReaderToolbarVisibilityModifier: ViewModifier {
    let layout: ReaderNavigationLayout

    func body(content: Content) -> some View {
#if os(iOS)
        let content = content.toolbar(layout.usesSystemToolbar ? .visible : .hidden, for: .navigationBar)
#endif
#if compiler(>=6.4) && os(iOS)
        if #available(iOS 27.0, *) {
            content.toolbarMinimizationBehavior(.never, for: .navigationBar, .bottomBar)
        } else {
            content
        }
#else
        content
#endif
    }
}
