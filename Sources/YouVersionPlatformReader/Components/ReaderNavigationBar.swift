import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// Custom navigation in ordinary windows; its contents do not depend on a width breakpoint.
struct ReaderNavigationBar: View {
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
                    if let action = layout.primaryAction {
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
        .padding(.vertical, 8)
        .background {
            if isUpperBar {
                viewModel.readerCanvasPrimaryColor
            } else {
                LinearGradient(
                    colors: [viewModel.readerCanvasPrimaryColor.opacity(0), viewModel.readerCanvasPrimaryColor],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
    }

    private var upperBar: some View {
        let leading = max(12, cornerInsets.leading)
        let trailing = max(12, cornerInsets.trailing)
        let actionsWidth: CGFloat = layout.upperAction == nil ? 44 : 96
        // Center in the whole window only when both sides have enough clearance.
        let centeredWidth = width - 2 * max(leading, trailing + actionsWidth + 8)
        return Group {
            if layout.placement == .bottomBar {
                upperActions.frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, leading)
                    .padding(.trailing, trailing)
            } else if centeredWidth >= preferredPickerWidth {
                ReaderNavigationPickers(
                    width: preferredPickerWidth, includesArrows: true, usesNativeBackground: false
                )
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    upperActions.padding(.trailing, trailing)
                }
            } else {
                HStack(spacing: 8) {
                    ReaderNavigationPickers(
                        width: max(0, width - leading - trailing - actionsWidth - 8),
                        includesArrows: true, usesNativeBackground: false,
                        fillsAvailableWidth: true
                    )
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
            ReaderNavigationMenu(actions: layout.menuActions)
        }
    }

}

/// Fixed label budgets keep localized title length from changing the arrangement.
struct ReaderNavigationPickers: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var chapterMaximumWidth = 200
    @ScaledMetric(relativeTo: .subheadline) private var versionMaximumWidth = 80
    let width: CGFloat
    let includesArrows: Bool
    let usesNativeBackground: Bool
    var fillsAvailableWidth = false

    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize && !usesNativeBackground
        let layout = isStacked ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        let arrowsWidth: CGFloat = includesArrows ? 88 : 0
        let availableWidth = max(0, width - arrowsWidth - 24)
        let versionWidth = min(versionMaximumWidth, max(44, availableWidth * 0.35))
        let chapterWidth = fillsAvailableWidth ? max(32, availableWidth - versionWidth)
            : min(chapterMaximumWidth, max(32, availableWidth - versionWidth))
        layout {
            HStack(spacing: 0) {
                if includesArrows {
                    chapterArrow(isNext: false)
                }
                Button { viewModel.showingBookPicker = true } label: {
                    Text(chapterTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(isStacked ? 2 : 1)
                        .truncationMode(.middle)
                        .frame(width: isStacked ? min(chapterMaximumWidth, max(32, width - arrowsWidth - 16)) : chapterWidth)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("bookAndChapterPickerBtn")
                if includesArrows {
                    chapterArrow(isNext: true)
                }
            }
            .padding(.horizontal, includesArrows ? 0 : 8)
            .modifier(ReaderNavigationCapsule(isEnabled: !usesNativeBackground))
            Button {
                viewModel.versionsViewModel.openVersionsStack(currentBibleLanguage: viewModel.version?.languageTag ?? "en")
            } label: {
                Text(versionTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(isStacked ? 2 : 1)
                    .truncationMode(.middle)
                    .frame(width: isStacked ? min(versionMaximumWidth, width - 16) : versionWidth)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("versionPickerBtn")
            .modifier(ReaderNavigationCapsule(isEnabled: !usesNativeBackground))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.version == nil)
    }

    private func chapterArrow(isNext: Bool) -> some View {
        Button {
            if isNext {
                viewModel.goToNextChapter()
            } else {
                viewModel.goToPreviousChapter()
            }
        } label: {
            Image(systemName: isNext ? "chevron.forward" : "chevron.backward")
                .font(.subheadline.weight(.medium))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(isNext ? String.localized("nextChapterAriaLabel") : String.localized("previousChapterAriaLabel"))
        .accessibilityIdentifier(isNext ? "nextChapterBtn" : "previousChapterBtn")
    }

    private var chapterTitle: String {
        if viewModel.showBookIntro,
           let book = viewModel.version?.book(with: viewModel.reference.bookId), let intro = book.intro {
            return "\(book.title ?? "") \(intro.title ?? "")"
        }
        return "\(viewModel.version?.bookName(viewModel.reference.bookId) ?? viewModel.reference.bookId) \(viewModel.reference.chapter)"
    }

    private var versionTitle: String {
        viewModel.version?.localizedAbbreviation ?? viewModel.version?.abbreviation ?? String(viewModel.reference.versionId)
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

struct ReaderNavigationActionButton: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let action: BibleReaderNavigationAction
    var isMenuItem = false

    var body: some View {
        Button {
            if action == .search {
                viewModel.openSearch()
            }
        } label: {
            if isMenuItem {
                Label(title, systemImage: systemImage)
            } else {
                Image(systemName: systemImage)
                    .font(.title3)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(action == .search ? "searchBtn" : "audioBtn")
    }

    private var systemImage: String {
        action == .search ? "magnifyingglass" : "play.fill"
    }

    private var title: String {
        switch action {
        case .search: String.localized("generic.search")
        // Audio is an explicitly requested placeholder. Add its upstream catalog key with playback.
        case .audio: String(localized: "Audio", bundle: .module)
        }
    }
}

struct ReaderNavigationMenu: View {
    let actions: [BibleReaderNavigationAction]

    var body: some View {
        BibleReaderHeaderMenuView(actions: actions)
    }
}
