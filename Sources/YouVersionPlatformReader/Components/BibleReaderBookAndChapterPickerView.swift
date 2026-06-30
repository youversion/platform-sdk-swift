import SwiftUI
import YouVersionPlatformCore

public struct BibleReaderBookAndChapterPickerView: View {
    @Binding var expandedBookCode: String?
    @Binding var isPresented: Bool
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let bookCodes: [String]
    let versionId: Int
    let bookNameProvider: (String) -> String?
    let chapterLabelsProvider: (String) -> [String]
    let introPassageId: (String) -> String?
    let onSelectionChange: ((Int, String, Int?, String?) -> Void)?

    private let chapterGridColumns = 5
    private let chapterButtonSize: CGFloat = 56
    
    public init(
        expandedBookCode: Binding<String?>,
        isPresented: Binding<Bool>,
        bookCodes: [String],
        versionId: Int,
        bookNameProvider: @escaping (String) -> String?,
        chapterLabelsProvider: @escaping (String) -> [String],
        introPassageId: @escaping (String) -> String?,
        onSelectionChange: ((Int, String, Int?, String?) -> Void)? = nil
    ) {
        self._expandedBookCode = expandedBookCode
        self._isPresented = isPresented
        self.bookCodes = bookCodes
        self.versionId = versionId
        self.bookNameProvider = bookNameProvider
        self.chapterLabelsProvider = chapterLabelsProvider
        self.introPassageId = introPassageId
        self.onSelectionChange = onSelectionChange
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    Button(String.localized("generic.cancel")) {
                        isPresented = false
                    }.padding(.leading, 16)
                    HStack {
                        Spacer()
                        Text(String.localized("bookChapterPicker.title"))
                            .font(.headline)
                        Spacer()
                    }
                }
                .padding(.vertical, 16)
                ScrollViewReader { proxy in
                    List {
                        ForEach(bookCodes, id: \.self) { bookCode in
                            bookRow(bookCode)
                            if expandedBookCode == bookCode {
                                chapterListView(bookCode)
                                    .bookPickerRow(background: viewModel.readerCanvasPrimaryColor, verticalInset: 0)
                            }
                        }
                    }
                    .background(viewModel.readerCanvasPrimaryColor)
                    .listStyle(.plain)
                    .onAppear {
                        if let expandedBookCode {
                            proxy.scrollTo(expandedBookCode, anchor: .top)
                        }
                    }
                }
            }
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .background(viewModel.readerCanvasPrimaryColor)
    }

    private func bookRow(_ bookCode: String) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .default) {
                expandedBookCode = expandedBookCode == bookCode ? nil : bookCode
            }
        } label: {
            HStack(spacing: 8) {
                Text(bookNameProvider(bookCode) ?? bookCode)
                    .font(.body)
                Spacer(minLength: 4)
                Image(systemName: expandedBookCode == bookCode ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(bookCode)
        .bookPickerRow(background: viewModel.readerCanvasPrimaryColor, verticalInset: 8)
    }

    private func chapterListView(_ bookCode: String) -> some View {
        let chapters = chapterLabelsProvider(bookCode)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: chapterGridColumns)
        return LazyVGrid(columns: columns, spacing: 16) {
            if let introId = introPassageId(bookCode) {
                Button(action: {
                    isPresented = false
                    onSelectionChange?(versionId, bookCode, nil, introId)
                }) {
                    chapterListButton(Text(Image("i-icon", bundle: .YouVersionUIBundle)))
                }
                .buttonStyle(.plain)
            }
            ForEach(Array(chapters.enumerated()), id: \.offset) { idx, label in
                Button(action: {
                    isPresented = false
                    onSelectionChange?(versionId, bookCode, idx + 1, nil)
                }) {
                    chapterListButton(Text(label))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func chapterListButton(_ text: Text) -> some View {
        text
            .font(.system(size: 14, weight: .bold))
            .frame(width: chapterButtonSize, height: chapterButtonSize)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(viewModel.readerButtonPrimaryColor)
            )
    }
}

#Preview {
    @State @Previewable var expandedBook: String? = "EXO"
    @State @Previewable var isPresented = true
    
    let sampleBookCodes = ["GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "JHN"]
    
    return BibleReaderBookAndChapterPickerView(
        expandedBookCode: $expandedBook,
        isPresented: $isPresented,
        bookCodes: sampleBookCodes,
        versionId: 1,
        bookNameProvider: { bookCode in
            switch bookCode {
            case "GEN": return "Genesis"
            case "EXO": return "Exodus"
            case "JHN": return "John"
            default: return bookCode
            }
        },
        chapterLabelsProvider: { _ in
            Array(1...21).map { String($0) }
        },
        introPassageId: { _ in "INTRO" },
        onSelectionChange: { versionId, book, chapter, passageId in
            print("Selected: Version \(versionId), Book \(book), Chapter \(chapter ?? 999), Passage \(passageId ?? "nil")")
        }
    )
    .environment(BibleReaderViewModel.preview)
}

private extension View {
    /// Shared row styling for the book/chapter picker list: a full-width canvas
    /// background, hidden separators, and horizontal insets with a configurable
    /// vertical inset.
    func bookPickerRow(background: Color, verticalInset: CGFloat) -> some View {
        listRowInsets(EdgeInsets(top: verticalInset, leading: 16, bottom: verticalInset, trailing: 16))
            .listRowBackground(background)
            .listRowSeparator(.hidden)
    }
}
