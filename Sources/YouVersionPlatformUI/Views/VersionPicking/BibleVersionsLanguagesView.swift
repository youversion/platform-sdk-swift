import SwiftUI

struct BibleVersionsLanguagesView: View {
    @Environment(BibleVersionsViewModel.self) private var viewModel

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
                        .textFieldStyle(.plain)
                        .focused($searchFieldIsFocused)
                        .autocorrectionDisabled(true)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .padding(8)
                        .foregroundStyle(viewModel.readerTextPrimaryColor)
                        .background(
                            Capsule()
                                .fill(viewModel.readerButtonPrimaryColor)
                        )
                    Button(String.localized("generic.cancel")) {
                        selectedSegment = .suggested
                    }
                    .padding(.trailing)
                }
                Divider()
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
                            .font(YouVersionFonts.fontHeaderM)
                            .padding(.leading)
                    }
                    ForEach(languageCodes, id: \.self) { language in
                        HStack {
                            Text(viewModel.languageName(language))
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
        .onAppear {
#if canImport(UIKit)
            UISegmentedControl.appearance().tintColor = UIColor(viewModel.readerButtonPrimaryColor)
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(viewModel.readerButtonContrastColor)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(viewModel.readerTextPrimaryColor)], for: .normal)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(viewModel.readerTextInvertedColor)], for: .selected)
#endif
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .customBackButton {
            viewModel.versionsStackPop()
        }
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .title) {
                Text(String.localized("languageList.title"))
                    .fontWeight(.medium)
                    .foregroundStyle(viewModel.readerTextPrimaryColor)
            }
#endif
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
        guard let versionsInfo = viewModel.permittedVersionsList else {
            return []
        }
        return Array(Set(versionsInfo.compactMap { $0.languageTag }))
    }

    private var languageCodes: [String] {
        switch selectedSegment {
        case .suggested:
            return viewModel.suggestedLanguages
        case .all:
            return sortedUnique(allPermittedLanguages)
        case .searching:
            return sortedUnique(allPermittedLanguages.filter {
                searchText.isEmpty ||
                $0.localizedCaseInsensitiveContains(searchText) ||
                viewModel.languageName($0).localizedCaseInsensitiveContains(searchText)
            })
        }
    }

    // De-dup + locale-aware, case-insensitive sort
    private func sortedUnique(_ items: [String]) -> [String] {
        let list = Array(Set(items)).map {
            LanguageAndCode(language: viewModel.languageName($0), code: $0)
        }
        return list.sorted().map { $0.code }
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
    BibleVersionsLanguagesView()
        .environment(BibleVersionsViewModel.preview)
}
