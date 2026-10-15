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
/// Visibility and minimization remain host-owned unless its stack is dedicated to the reader.
struct ReaderToolbarModifier: ViewModifier {
    let layout: ReaderNavigationLayout

    func body(content: Content) -> some View {
        Group {
#if compiler(>=6.4) && os(iOS)
            if #available(iOS 27.1, *), layout.usesSystemToolbar {
                content.toolbar {
                    ReaderSystemToolbar(layout: layout)
                }
            } else {
                content
            }
#else
            content
#endif
        }
        .modifier(ReaderNavigationBarOwnershipModifier(layout: layout))
    }
}

/// Only a dedicated host stack grants permission to hide or pin the system navigation bar.
private struct ReaderNavigationBarOwnershipModifier: ViewModifier {
    let layout: ReaderNavigationLayout

    func body(content: Content) -> some View {
#if os(iOS)
        if layout.navigationStackUsage == .justForReader {
#if compiler(>=6.4)
            if #available(iOS 27.1, *), layout.usesSystemToolbar {
                content
                    .toolbarVisibility(.visible, for: .navigationBar)
                    .toolbarMinimizationBehavior(.never, for: .navigationBar)
            } else {
                content.toolbar(.hidden, for: .navigationBar)
            }
#else
            content.toolbar(.hidden, for: .navigationBar)
#endif
        } else {
            content
        }
#else
        content
#endif
    }
}
