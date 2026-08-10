import SwiftUI
import YouVersionPlatformCore

public struct BibleReaderBookAndChapterPickerView: View {
    @Binding var expandedBookCode: String?
    @Binding var isPresented: Bool
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollPositionBookCode: String?
    @State private var isScrollPositionActive = true

    let bookCodes: [String]
    let versionId: Int
    let bookNameProvider: (String) -> String?
    let chapterLabelsProvider: (String) -> [String]
    let introPassageId: (String) -> String?
    let onSelectionChange: ((Int, String, Int?, String?) -> Void)?

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
        self.init(
            expandedBookCode: expandedBookCode,
            isPresented: isPresented,
            initialBookCode: nil,
            bookCodes: bookCodes,
            versionId: versionId,
            bookNameProvider: bookNameProvider,
            chapterLabelsProvider: chapterLabelsProvider,
            introPassageId: introPassageId,
            onSelectionChange: onSelectionChange
        )
    }

    init(
        expandedBookCode: Binding<String?>,
        isPresented: Binding<Bool>,
        initialBookCode: String?,
        bookCodes: [String],
        versionId: Int,
        bookNameProvider: @escaping (String) -> String?,
        chapterLabelsProvider: @escaping (String) -> [String],
        introPassageId: @escaping (String) -> String?,
        onSelectionChange: ((Int, String, Int?, String?) -> Void)? = nil
    ) {
        self._expandedBookCode = expandedBookCode
        self._isPresented = isPresented
        self._scrollPositionBookCode = State(initialValue: initialBookCode)
        self.bookCodes = bookCodes
        self.versionId = versionId
        self.bookNameProvider = bookNameProvider
        self.chapterLabelsProvider = chapterLabelsProvider
        self.introPassageId = introPassageId
        self.onSelectionChange = onSelectionChange
    }

    private var initialScrollPositionBookCodeBinding: Binding<String?> {
        Binding(
            get: { isScrollPositionActive ? scrollPositionBookCode : nil },
            set: { bookCode in
                if isScrollPositionActive {
                    scrollPositionBookCode = bookCode
                }
            }
        )
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .padding(.leading, 16)
                    HStack {
                        Spacer()
                        Text(String.localized("bookChapterPicker.title"))
                            .font(.headline)
                        Spacer()
                    }
                }
                .padding(.vertical, 16)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(bookCodes, id: \.self) { bookCode in
                            ZStack(alignment: .leading) {
                                viewModel.readerCanvasPrimaryColor
                                bookButton(bookCode)
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: 44)
                                    .background(viewModel.reference.bookId == bookCode && (expandedBookCode != bookCode) ? viewModel.readerSurfaceTertiaryColor : .clear)
                            }
                            .id(bookCode)
                            if expandedBookCode == bookCode {
                                chapterListView(bookCode)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .frame(maxWidth: 500)
                }
                .background(viewModel.readerCanvasPrimaryColor)
                .scrollPosition(id: initialScrollPositionBookCodeBinding, anchor: .center)
            }
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .background(viewModel.readerCanvasPrimaryColor)
    }

    private func bookButton(_ bookCode: String) -> some View {
        Button {
            isScrollPositionActive = false
            scrollPositionBookCode = nil
            withAnimation(reduceMotion ? nil : .default) {
                expandedBookCode = expandedBookCode == bookCode ? nil : bookCode
            }
        } label: {
            HStack {
                Text(bookNameProvider(bookCode) ?? bookCode)
                    .font(.body)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chapterListView(_ bookCode: String) -> some View {
        let chapters = chapterLabelsProvider(bookCode)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 5)
        return LazyVGrid(columns: columns, spacing: 0) {
            if let introId = introPassageId(bookCode) {
                Button(action: {
                    isPresented = false
                    onSelectionChange?(versionId, bookCode, nil, introId)
                }) {
                    let img = Image("i-icon", bundle: .YouVersionUIBundle)
                        .renderingMode(.template)
                    chapterListButton(Text(img))
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
    }
    
    private func chapterListButton(_ text: Text) -> some View {
        text
            .font(.system(size: 18, weight: .bold))
            .frame(height: 48)
            .frame(maxWidth: 96)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(viewModel.readerButtonPrimaryColor)
            )
            .padding(2)
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
