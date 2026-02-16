import SwiftUI
import YouVersionPlatformCore

public struct BibleReaderBookAndChapterPickerView: View {
    @Binding var expandedBookCode: String?
    @Binding var isPresented: Bool
    @Environment(BibleReaderViewModel.self) private var viewModel

    let bookCodes: [String]
    let versionId: Int
    let bookNameProvider: (String) -> String?
    let chapterLabelsProvider: (String) -> [String]
    let hasIntroPassage: (String) -> Bool
    let onSelectionChange: ((Int, String, Int?) -> Void)?

    private let chapterGridColumns = 5
    private let chapterButtonSize: CGFloat = 56
    
    public init(
        expandedBookCode: Binding<String?>,
        isPresented: Binding<Bool>,
        bookCodes: [String],
        versionId: Int,
        bookNameProvider: @escaping (String) -> String?,
        chapterLabelsProvider: @escaping (String) -> [String],
        hasIntroPassage: @escaping (String) -> Bool,
        onSelectionChange: ((Int, String, Int?) -> Void)? = nil
    ) {
        self._expandedBookCode = expandedBookCode
        self._isPresented = isPresented
        self.bookCodes = bookCodes
        self.versionId = versionId
        self.bookNameProvider = bookNameProvider
        self.chapterLabelsProvider = chapterLabelsProvider
        self.hasIntroPassage = hasIntroPassage
        self.onSelectionChange = onSelectionChange
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text(String.localized("bookChapterPicker.title"))
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 16)
                List {
                    ForEach(bookCodes, id: \.self) { bookCode in
                        Section {
                            if expandedBookCode == bookCode {
                                chapterListView(bookCode)
                            }
                        } header: {
                            ZStack(alignment: .leading) {
                                viewModel.readerCanvasPrimaryColor
                                sectionHeaderView(bookCode)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 16)
                            }
                            .listRowInsets(EdgeInsets())
                        }
                        .listRowBackground(viewModel.readerCanvasPrimaryColor)
                    }
                }
                .background(viewModel.readerCanvasPrimaryColor)
                .listStyle(PlainListStyle())
            }
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .background(viewModel.readerCanvasPrimaryColor)
    }

    private func sectionHeaderView(_ bookCode: String) -> some View {
        HStack(spacing: 8) {
            Text(bookNameProvider(bookCode) ?? bookCode)
                .font(.body)
            Spacer(minLength: 4)
            Image(systemName: expandedBookCode == bookCode ? "chevron.up" : "chevron.down")
                .font(.system(size: 14))
        }
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        .onTapGesture {
            withAnimation {
                expandedBookCode = expandedBookCode == bookCode ? nil : bookCode
            }
        }
        .textCase(nil)
    }

    private func chapterListView(_ bookCode: String) -> some View {
        let chapters = chapterLabelsProvider(bookCode)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: chapterGridColumns)
        return LazyVGrid(columns: columns, spacing: 10) {
            if hasIntroPassage(bookCode) {
                Button(action: {
                    isPresented = false
                    onSelectionChange?(versionId, bookCode, nil)
                }) {
                    chapterListButton("ⓘ")
                }
                .buttonStyle(PlainButtonStyle())
            }
            ForEach(chapters.indices, id: \.self) { idx in
                Button(action: {
                    isPresented = false
                    onSelectionChange?(versionId, bookCode, idx + 1)
                }) {
                    chapterListButton(chapters[idx])
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
    
    private func chapterListButton(_ label: String) -> some View {
        Text(label)
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
        hasIntroPassage: { _ in true },
        onSelectionChange: { versionId, book, chapter in
            print("Selected: Version \(versionId), Book \(book), Chapter \(chapter)")
        }
    )
    .environment(BibleReaderViewModel.preview)
}
