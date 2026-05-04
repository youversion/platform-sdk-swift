import SwiftUI
import YouVersionPlatformCore

public struct BibleVersionsListView: View {
    @Environment(BibleVersionsViewModel.self) private var viewModel
    @State private var searchText = ""

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.bibleVersionStatisticsPromo.isEmpty {
                Color.clear.frame(height: 72)
            }
            searchInput
            Button {
                viewModel.languageTapped()
            } label: {
                languageDisplay
            }
            .buttonStyle(.plain)
            Group {
                if let versions = filteredVersions {
                    List(versions, id: \.id) { version in
                        Button {
                            viewModel.handleVersionPickerTap(version.id)
                        } label: {
                            BibleVersionOverviewListItem(version: version)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(viewModel.readerCanvasPrimaryColor)
#if !os(tvOS)
                        .listRowSeparator(.hidden)
#endif
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain)
                } else {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(viewModel.readerTextMutedColor)
                        Spacer()
                    }
                }
            }
        }
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .title) {
                Text(viewModel.bibleVersionStatisticsPromo)
                    .fontWeight(.medium)
                    .foregroundStyle(viewModel.readerTextPrimaryColor)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
#endif
        .customBackButton {
            viewModel.versionsStackPop()
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .background(viewModel.readerCanvasPrimaryColor)
        .onChange(of: viewModel.activeLanguage, initial: true) { _, newValue in
            viewModel.fetchVersions(forLanguageTag: newValue)
        }
    }

    private var searchInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .imageScale(.medium)
                .foregroundStyle(.secondary)
            TextField(
                "",
                text: $searchText,
                prompt: Text(String.localized("versionList.searchPlaceholder"))
                    .foregroundStyle(viewModel.readerTextMutedColor)
            )
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
                .fill(viewModel.readerButtonPrimaryColor)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var languageDisplay: some View {
        let language = viewModel.activeLanguage
        let versionsInLanguage = viewModel.cachedPermittedVersions?.filter { $0.languageTag == language } ?? []
        return HStack {
            Image(systemName: "globe")
            Text(viewModel.languageName(language))
            Text(String(versionsInLanguage.count))
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(viewModel.readerButtonPrimaryColor)
                )
            Image(systemName: "chevron.right")
            Spacer()
        }
        .padding()
    }

    private var filteredVersions: [BibleVersion]? {
        let language = viewModel.activeLanguage
        guard let versionsList = viewModel.versionsByLanguageTag[language] else {
            return nil
        }

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return versionsList
        }
        let query = searchText.lowercased()
        return versionsList.filter { v in
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
    BibleVersionsListView()
        .environment(BibleVersionsViewModel.preview)
}
