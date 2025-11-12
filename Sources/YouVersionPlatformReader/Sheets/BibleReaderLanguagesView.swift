import SwiftUI

struct BibleReaderLanguagesView: View, ReaderColors {
    @Environment(BibleReaderViewModel.self) private var viewModel

    enum Segment: String, CaseIterable, Identifiable {
        case suggested
        case all
        case searching

        var id: String { rawValue }
    }

    @State private var selectedSegment: Segment = .suggested
    @State private var searchText = ""
    @FocusState private var searchFieldIsFocused

    var body: some View {
        VStack(alignment: .leading) {
            if selectedSegment == .searching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.leading)
                    TextField(String.localized("generic.search"), text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .focused($searchFieldIsFocused)
                        .disableAutocorrection(true)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .padding(8)
                    Button(String.localized("generic.cancel")) {
                        selectedSegment = .suggested
                    }
                    .padding(.trailing)
                }
                .background(buttonPrimaryColor)
            } else {
                Picker("", selection: $selectedSegment) {
                    let allMsg = String(
                        format: String.localized("languageList.allWithCount"),
                        allPermittedLanguages.count,
                        String.localized("languageList.all")
                    )
                    Text(String.localized("languageList.suggested"))
                        .tag(Segment.suggested)
                    Text(allMsg)
                        .tag(Segment.all)
                }
                .pickerStyle(.segmented)
                .padding()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if selectedSegment == .suggested {
                        Text(String.localized("languageList.regional"))
                            .font(ReaderFonts.fontHeaderM)
                            .padding(.leading)
                    }
                    ForEach(languageCodes, id: \.self) { language in
                        HStack {
                            Text(Self.languageName(language))
                            Spacer()
                        }
                        .frame(minHeight: 44)
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.chosenLanguage = language
                            viewModel.versionsStackPop()
                        }
                    }
                }
            }

        }
        .navigationTitle(String.localized("languageList.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .customBackButton {
            viewModel.versionsStackPop()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    searchFieldIsFocused = true
                    selectedSegment = .searching
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .background(viewModel.readerCanvasPrimaryColor)
        .foregroundStyle(viewModel.readerTextPrimaryColor)
    }

    // MARK: - Helpers

    private var allPermittedLanguages: [String] {
        Array(Set(viewModel.permittedVersions.compactMap { $0.languageTag }))
    }

    private var languageCodes: [String] {
        switch selectedSegment {
        case .suggested:
            return viewModel.suggestedLanguages
        case .all:
            return Self.sortedUnique(allPermittedLanguages)
        case .searching:
            return Self.sortedUnique(allPermittedLanguages.filter {
                searchText.isEmpty ||
                $0.localizedCaseInsensitiveContains(searchText) ||
                Self.languageName($0).localizedCaseInsensitiveContains(searchText)
            })
        }
    }

    // De-dup + locale-aware, case-insensitive sort
    private static func sortedUnique(_ items: [String]) -> [String] {
        let list = Array(Set(items)).map {
            LanguageAndCode(language: languageName($0), code: $0)
        }
        return list.sorted().map { $0.code }
    }

    // We might need to look up the language name from the YouVersion API instead of this.
    private static func languageName(_ lang: String) -> String {
        Locale.current.localizedString(forLanguageCode: lang) ?? lang
    }

    private struct LanguageAndCode: Comparable {
        let language: String
        let code: String

        static func < (lhs: LanguageAndCode, rhs: LanguageAndCode) -> Bool {
            lhs.language.localizedCaseInsensitiveCompare(rhs.language) == .orderedAscending
        }

        static func == (lhs: LanguageAndCode, rhs: LanguageAndCode) -> Bool {
            lhs.language == rhs.language
        }
    }
}

#Preview {
    BibleReaderLanguagesView()
        .environment(BibleReaderViewModel.preview)
}
