import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// Fixed label budgets keep localized title length from changing the arrangement.
/// The compact overlay retains the expanded pickers' size so collapsing chrome
/// does not itself move the scroll content and reverse the scroll-driven state.
struct ReaderNavigationPickers: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    .frame(width: isStacked ? min(versionMaximumWidth, max(0, width - 16)) : versionWidth)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("versionPickerBtn")
            .modifier(ReaderNavigationCapsule(isEnabled: !usesNativeBackground))
        }
        .buttonStyle(.plain)
        .opacity(viewModel.showChrome ? 1 : 0)
        .allowsHitTesting(viewModel.showChrome)
        .accessibilityHidden(!viewModel.showChrome)
        .overlay {
            if !viewModel.showChrome {
                compactNavigation
            }
        }
        .disabled(viewModel.version == nil)
    }

    private var compactNavigation: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                viewModel.showChrome = true
            }
        } label: {
            HStack(spacing: 8) {
                Text(chapterTitle)
                Divider().frame(height: 14)
                Text(versionTitle)
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("readerCompactNavigationBtn")
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
                .readerIconButton()
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
