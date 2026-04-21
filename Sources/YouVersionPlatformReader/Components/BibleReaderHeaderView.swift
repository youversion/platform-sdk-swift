import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

public struct BibleReaderHeaderView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let showChrome: Bool
    let onSelectionChange: ((Int, String, Int?, String?) -> Void)?
    let onCompactTap: (() -> Void)?

    @State private var spaceNeeded = false

    init(
        showChrome: Bool = true,
        onSelectionChange: ((Int, String, Int?, String?) -> Void)? = nil,
        onCompactTap: (() -> Void)? = nil
    ) {
        self.showChrome = showChrome
        self.onSelectionChange = onSelectionChange
        self.onCompactTap = onCompactTap
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var bindableVersionsViewModel = viewModel.versionsViewModel

        HStack {
            if showChrome {
                HStack {
                    halfPillPickers
                    Spacer()
                    BibleReaderHeaderMenuView()
                }
                .transition(reduceMotion ? .identity : .opacity)
            } else {
                compactLabels
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .padding(.leading, 16)
        .padding(.top, spaceNeeded ? 32 : 0)  // hack. See below.
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.width, initial: true) { _, w in
                        // This enables a hack to avoid overlapping the red/yellow/green
                        // buttons on iPad running 26+. iPadOS changes the layout and adds
                        // those buttons, such that we need different top padding.
#if canImport(UIKit)
                        if #available(iOS 26, *) {
                            spaceNeeded = UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .compact
                        }
#endif
                    }
            }
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: showChrome)
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
                    bookCodes: version.bookUSFMs,
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
    private var halfPillPickers: some View {
        if let version = viewModel.version {
            let title = viewModel.showBookIntro ? introString : bookAndChapter

            halfPillPickersView(
                bookAndChapter: title,
                versionAbbreviation: version.localizedAbbreviation ?? version.abbreviation ?? String(version.id),
                handleChapterTap: { viewModel.showingBookPicker.toggle() },
                handleVersionTap: { viewModel.versionsViewModel.openVersionsStack(currentBibleLanguage: version.languageTag ?? "en") }
            )
        } else {
            halfPillPickersView(
                bookAndChapter: "",
                versionAbbreviation: "",
                handleChapterTap: {},
                handleVersionTap: {}
            )
        }
    }

    private func halfPillPickersView(
        bookAndChapter: String,
        versionAbbreviation: String,
        handleChapterTap: @escaping () -> Void,
        handleVersionTap: @escaping () -> Void
    ) -> some View {
        BibleReaderHalfPillPickersView(
            bookAndChapter: bookAndChapter,
            versionAbbreviation: versionAbbreviation,
            handleChapterTap: handleChapterTap,
            handleVersionTap: handleVersionTap,
            foregroundColor: viewModel.readerTextPrimaryColor,
            buttonColor: viewModel.readerButtonPrimaryColor,
            backgroundColor: viewModel.readerCanvasPrimaryColor,
            compactMode: false
        )
    }

    private var bookAndChapter: String {
        guard let version = viewModel.version else {
            return ""
        }
        return "\(version.bookName(viewModel.reference.bookUSFM) ?? viewModel.reference.bookUSFM) \(String(viewModel.reference.chapter))"
    }

    private var introString: String {
        guard let book = viewModel.version?.book(with: viewModel.reference.bookUSFM),
              let intro = book.intro
        else {
            return ""
        }
        return "\(book.title ?? "") \(intro.title ?? "")"
    }

    @ViewBuilder
    private var compactLabels: some View {
        if let version = viewModel.version {
            compactLabelsView(
                bookAndChapter: bookAndChapter,
                versionAbbreviation: version.localizedAbbreviation ?? version.abbreviation ?? String(version.id)
            )
        } else {
            compactLabelsView(bookAndChapter: "", versionAbbreviation: "")
        }
    }

    private func compactLabelsView(bookAndChapter: String, versionAbbreviation: String) -> some View {
        HStack(spacing: 8) {
            Text(bookAndChapter)
                .font(.system(size: 14, weight: .semibold))

            Divider()
                .frame(width: 1, height: 14)

            Text(versionAbbreviation)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .frame(height: 24)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                onCompactTap?()
            }
        }
    }

}

#Preview {
    VStack {
        Divider()
        BibleReaderHeaderView(
            showChrome: true,
            onSelectionChange: { versionId, book, chapter, passageId in
                print("Version: \(versionId), Book: \(book), Chapter: \(chapter ?? 999), Passage: \(passageId ?? "nil")")
            }
        )
        Divider()
        BibleReaderHeaderView(
            showChrome: false,
            onSelectionChange: { versionId, book, chapter, passageId in
                print("Version: \(versionId), Book: \(book), Chapter: \(chapter ?? 999), Passage: \(passageId ?? "nil")")
            }, onCompactTap: {
                print("Compact header tapped!")
            }
        )
        Divider()
    }
    .environment(BibleReaderViewModel.preview)
}
