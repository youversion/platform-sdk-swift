import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

public struct BibleReaderVersionListView: View, ReaderColors {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @State private var searchText = ""

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.bibleVersionStatisticsPromo.isEmpty {
                Color.clear.frame(height: 72)
            }
            searchInput
            languageDisplay
                .onTapGesture {
                    viewModel.versionsStackPush(to: .languages)
                }
            Group {
                if viewModel.permittedVersions.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(viewModel.readerTextMutedColor)
                        Spacer()
                        Spacer()
                    }
                } else {
                    List(filteredVersions, id: \.id) { v in
                        BibleVersionOverviewListItem(item: v)
                            .listRowBackground(viewModel.readerCanvasPrimaryColor)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .onTapGesture {
                                viewModel.handleVersionPickerTap(v.id)
                            }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .navigationTitle(viewModel.bibleVersionStatisticsPromo)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .customBackButton {
            viewModel.versionsStackPop()
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .background(viewModel.readerCanvasPrimaryColor)
    }

    private var searchInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .imageScale(.medium)
                .foregroundStyle(.secondary)
            TextField("", text: $searchText, prompt: Text(String.localized("versionList.searchPlaceholder")))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled(true)
                .accessibilityLabel(String.localized("versionList.searchPlaceholder"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(buttonPrimaryColor)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // We might need to look up the language name from our own API instead of this.
    private func languageName(_ lang: String) -> String {
        Locale.current.localizedString(forLanguageCode: lang) ?? lang
    }

    private var activeLanguage: String {
        viewModel.chosenLanguage ?? viewModel.version?.languageTag ?? "en"
    }
    private var languageDisplay: some View {
        let language = activeLanguage
        let versionsInLanguage = viewModel.permittedVersions.filter { $0.languageTag == language }
        return HStack {
            Image(systemName: "globe")
            Text(languageName(language))
            Text(String(versionsInLanguage.count))
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(buttonPrimaryColor)
                )
            Image(systemName: "chevron.right")
            Spacer()
        }
        .padding()
    }

    private var filteredVersions: [BibleVersion] {
        let language = activeLanguage
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return viewModel.permittedVersions.filter {
                $0.languageTag == language
            }
        }
        let query = searchText.lowercased()
        return viewModel.permittedVersions.filter { v in
            guard v.languageTag == language else {
                return false
            }
            let title = (v.title ?? "").lowercased()
            let abbr = (v.abbreviation ?? String(v.id)).lowercased()
            let lang = (v.languageTag ?? "")
            return title.contains(query) || abbr.contains(query) || lang.contains(query)
        }
    }

}

#Preview {
    BibleReaderVersionListView()
        .environment(BibleReaderViewModel.preview)
}
