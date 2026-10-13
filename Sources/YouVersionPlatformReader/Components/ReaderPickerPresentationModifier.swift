import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

/// Keeps picker presentations alive when navigation changes edge or presentation.
struct ReaderPickerPresentationModifier: ViewModifier {
    @Environment(BibleReaderViewModel.self) private var viewModel

    func body(content: Content) -> some View {
        @Bindable var viewModel = viewModel
        @Bindable var bindableVersionsViewModel = viewModel.versionsViewModel

        content
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
                        onSelectionChange: { version, book, chapter, _ in
                            Task {
                                let reference = BibleReference(versionId: version, bookId: book, chapter: chapter ?? 1)
                                await viewModel.onHeaderSelectionChange(reference, showIntro: chapter == nil)
                            }
                        }
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
}
