import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

public struct BibleReaderHeaderView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel

    private let accessory: AnyView?
    private let isCompact: Bool
    let onSelectionChange: ((Int, String, Int?, String?) -> Void)?

    init(
        onSelectionChange: ((Int, String, Int?, String?) -> Void)? = nil,
        accessory: AnyView? = nil,
        isCompact: Bool = false
    ) {
        self.accessory = accessory
        self.isCompact = isCompact
        self.onSelectionChange = onSelectionChange
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var bindableVersionsViewModel = viewModel.versionsViewModel

        HStack {
            if let accessory, !isCompact {
                accessory
                    .frame(minWidth: 44, minHeight: 44)
                    .background(isCompact ? Color.clear : buttonBackgroundColor, in: Capsule())
                    .shadow(color: isCompact ? .clear : viewModel.colorForScheme(light: viewModel.readerDropShadowColor, dark: .clear), radius: 8, y: 2)
            }
            navigationPickers
        }
        .padding(.vertical, isCompact ? 0 : 8)
        .sheet(
            isPresented: $viewModel.showingBookPicker,
            onDismiss: { viewModel.headerExpandedBookCode = nil }
        ) {
            if let version = viewModel.version,
               let books = version.books,
                !books.isEmpty {
                BibleReaderBookAndChapterPickerView(
                    expandedBookCode: $viewModel.headerExpandedBookCode,
                    isPresented: $viewModel.showingBookPicker,
                    initialBookCode: viewModel.reference.bookId,
                    bookCodes: version.bookIds,
                    versionId: viewModel.reference.versionId,
                    bookNameProvider: { bookCode in version.bookName(bookCode) },
                    chapterLabelsProvider: { bookCode in version.chapterLabels(bookCode) },
                    introPassageId: { bookCode in version.book(with: bookCode)?.intro?.passageId },
                    onSelectionChange: onSelectionChange
                )
            } else {
                ProgressView()
            }
        }
        .sheet(isPresented: $bindableVersionsViewModel.showingVersionsStack) {
            BibleVersionsStack()
                .environment(viewModel.versionsViewModel)
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var navigationPickers: some View {
        if let version = viewModel.version {
            let title = viewModel.showBookIntro ? introString : bookAndChapter

            navigationPickersView(
                bookAndChapter: title,
                versionAbbreviation: version.localizedAbbreviation ?? version.abbreviation ?? String(version.id),
                handleChapterTap: { viewModel.showingBookPicker.toggle() },
                handleVersionTap: { viewModel.versionsViewModel.openVersionsStack(currentBibleLanguage: version.languageTag ?? "en") }
            )
        } else {
            navigationPickersView(
                bookAndChapter: "",
                versionAbbreviation: "",
                handleChapterTap: {},
                handleVersionTap: {}
            )
        }
    }

    private func navigationPickersView(
        bookAndChapter: String,
        versionAbbreviation: String,
        handleChapterTap: @escaping () -> Void,
        handleVersionTap: @escaping () -> Void
    ) -> some View {
        let chapterPicker =
            HStack(spacing: 0) {
                if !isCompact {
                    Button(action: viewModel.goToPreviousChapter) {
                        Image(systemName: "chevron.backward")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(String.localized("previousChapterAriaLabel"))
                    .accessibilityIdentifier("previousChapterBtn")
                }
                Button(action: handleChapterTap) {
                    Text(bookAndChapter)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: isCompact ? 28 : 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("bookAndChapterPickerBtn")
                if !isCompact {
                    Button(action: viewModel.goToNextChapter) {
                        Image(systemName: "chevron.forward")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(String.localized("nextChapterAriaLabel"))
                    .accessibilityIdentifier("nextChapterBtn")
                }
            }
            .background(isCompact ? Color.clear : buttonBackgroundColor, in: Capsule())
            .shadow(color: isCompact ? .clear : viewModel.colorForScheme(light: viewModel.readerDropShadowColor, dark: .clear), radius: 8, y: 2)

        let versionPicker =
            Button(action: handleVersionTap) {
                Text(versionAbbreviation)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(minWidth: 44, minHeight: isCompact ? 28 : 44)
            }
            .background(isCompact ? Color.clear : buttonBackgroundColor, in: Capsule())
            .shadow(color: isCompact ? .clear : viewModel.colorForScheme(light: viewModel.readerDropShadowColor, dark: .clear), radius: 8, y: 2)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("versionPickerBtn")
        return HStack(spacing: 8) {
            chapterPicker
            versionPicker
        }
        .dynamicTypeSize(.medium)
        .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .buttonStyle(.plain)
        .disabled(viewModel.version == nil)
    }

    private var buttonBackgroundColor: Color {
        viewModel.colorForScheme(light: viewModel.readerWhiteColor, dark: viewModel.readerButtonPrimaryColor)
    }

    private var bookAndChapter: String {
        guard let version = viewModel.version else {
            return ""
        }
        return "\(version.bookName(viewModel.reference.bookId) ?? viewModel.reference.bookId) \(String(viewModel.reference.chapter))"
    }

    private var introString: String {
        guard let book = viewModel.version?.book(with: viewModel.reference.bookId),
              let intro = book.intro
        else {
            return ""
        }
        return "\(book.title ?? "") \(intro.title ?? "")"
    }

}

#Preview {
    BibleReaderHeaderView()
        .padding()
        .environment(BibleReaderViewModel.preview)
}

#Preview("Navigation with accessory") {
    BibleReaderHeaderView(accessory: AnyView(
        Button(action: {}) {
            Image(systemName: "magnifyingglass")
        }
        .accessibilityLabel(String.localized("generic.search"))
    ))
    .padding()
    .environment(BibleReaderViewModel.preview)
}
