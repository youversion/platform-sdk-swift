import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderSearchView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            searchHeader
            Divider()
            results
        }
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .background(viewModel.readerCanvasPrimaryColor)
        .task {
            isSearchFieldFocused = viewModel.searchQuery.isEmpty
        }
        .task(id: viewModel.searchQuery) {
            await viewModel.searchIfNeeded()
        }
    }

    private var searchHeader: some View {
        @Bindable var viewModel = viewModel

        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(viewModel.readerTextMutedColor)
                TextField(String.localized("generic.search"), text: $viewModel.searchQuery)
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)
                    .onChange(of: viewModel.searchQuery) { _, query in
                        if query.count > 100 {
                            viewModel.searchQuery = String(query.prefix(100))
                        }
                    }
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(viewModel.readerTextMutedColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String.localized("generic.cancel"))
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(viewModel.readerButtonSecondaryColor, in: Capsule())

            Button(String.localized("generic.done")) {
                viewModel.showingSearchSheet = false
            }
            .font(.callout.weight(.semibold))
        }
        .padding()
    }

    @ViewBuilder
    private var results: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
                    .tint(viewModel.readerTextMutedColor)
                    .accessibilityLabel(String.localized("generic.search"))
                    .padding(.vertical, 8)
            }

            if viewModel.searchFailed {
                searchStateView(
                    systemImage: "exclamationmark.circle",
                    title: String.localized("generic.error")
                )
            } else if viewModel.hasCompletedSearch && viewModel.searchResults.isEmpty {
                searchStateView(
                    systemImage: "magnifyingglass",
                    title: noResultsText
                )
            } else {
                searchResultsScrollView
            }
        }
    }

    private var searchResultsScrollView: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults, id: \.reference) { result in
                    resultButton(result)
                        .id(result.reference)
                }
            }
            .scrollTargetLayout()
            .frame(maxWidth: viewModel.readerMaxWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: $viewModel.searchScrollPosition, anchor: .top)
    }

    private var noResultsText: String {
        NSLocalizedString(
            "bibleReader.search.noResults",
            tableName: "Localizable",
            bundle: Bundle.YouVersionUIBundle,
            value: "No verses found.",
            comment: "Message shown when a Bible search returns no verses."
        )
    }

    private func searchStateView(systemImage: String, title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.body)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(viewModel.readerTextMutedColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func resultButton(_ result: YouVersionVerseSearchResult) -> some View {
        Button {
            isSearchFieldFocused = false
            Task {
                try? await ContinuousClock().sleep(for: .milliseconds(100))
                await viewModel.selectSearchResult(result)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(viewModel.readerTextPrimaryColor)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 7) {
                    if let text = viewModel.searchResultTextByUSFM[result.reference], !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    Text(referenceTitle(for: result))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(viewModel.readerTextMutedColor)
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task {
            await viewModel.loadVerseText(for: result)
        }
    }

    private func referenceTitle(for result: YouVersionVerseSearchResult) -> String {
        guard let reference = result.bibleReference(versionID: viewModel.reference.versionId) else {
            return result.reference
        }
        return viewModel.version?.displayTitle(for: reference, includesVersionAbbreviation: false) ?? result.reference
    }
}
