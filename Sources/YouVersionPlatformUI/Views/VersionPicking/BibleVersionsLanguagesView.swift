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
                        availableLanguageTags.count,
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
                            .font(YouVersionFonts.headerMedium)
                            .padding(.leading)
                    }
                    ForEach(languageTags, id: \.self) { language in
                        Button {
                            viewModel.chosenLanguage = language
                            viewModel.versionsStackPop()
                        } label: {
                            HStack {
                                Text(viewModel.languageName(language))
                                Spacer()
                            }
                            .frame(minHeight: 44)
                            .padding(.horizontal)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        }
        .task(id: viewModel.colorTheme) {
#if canImport(UIKit)
            let appearance = UISegmentedControl.appearance()
            appearance.tintColor = UIColor(viewModel.readerButtonPrimaryColor)
            appearance.selectedSegmentTintColor = UIColor(viewModel.readerButtonContrastColor)
            appearance.setTitleTextAttributes([.foregroundColor: UIColor(viewModel.readerTextPrimaryColor)], for: .normal)
            appearance.setTitleTextAttributes([.foregroundColor: UIColor(viewModel.readerTextInvertedColor)], for: .selected)
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

    private var availableLanguageTags: [String] {
        guard let versionsInfo = viewModel.cachedPermittedVersions else {
            return []
        }
        return Array(Set(versionsInfo.compactMap { $0.languageTag }))
    }

    private var languageTags: [String] {
        switch selectedSegment {
        case .suggested:
            return viewModel.suggestedLanguageTags
        case .all:
            return sortedUniqueLanguageTags(availableLanguageTags, languageName: viewModel.languageName)
        case .searching:
            let filtered = filteredLanguageTags(availableLanguageTags, matching: searchText, languageName: viewModel.languageName)
            return sortedUniqueLanguageTags(filtered, languageName: viewModel.languageName)
        }
    }
}

#Preview {
    BibleVersionsLanguagesView()
        .environment(BibleVersionsViewModel.preview)
}
