import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderSearchView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
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
            await viewModel.updateSuggestedSearchQueries()
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
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFieldFocused = false
                        Task {
                            await viewModel.search()
                        }
                    }
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
            if viewModel.isSearching || viewModel.isLoadingSearchQueries {
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
                    title: String.localized("bibleReader.search.noResults")
                )
            } else if viewModel.hasCompletedSearch {
                searchResultsScrollView
            } else {
                searchQueriesScrollView
            }
        }
    }

    private var searchQueriesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.suggestedSearchQueries, id: \.self) { query in
                    Button {
                        isSearchFieldFocused = false
                        Task {
                            await viewModel.search(for: query)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(viewModel.readerTextMutedColor)
                            Text(query.text)
                                .font(.body)
                                .foregroundStyle(viewModel.readerTextPrimaryColor)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: viewModel.readerMaxWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    private var searchResultsScrollView: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.reference) { index, result in
                    resultButton(result)
                        .id(result.reference)
                        .task(id: viewModel.nextSearchPageToken) {
                            let loadThreshold = max(0, viewModel.searchResults.count - 5)
                            guard index >= loadThreshold else {
                                return
                            }
                            await viewModel.loadNextSearchPageIfNeeded()
                        }
                }

                if viewModel.isLoadingNextSearchPage {
                    ProgressView()
                        .controlSize(.small)
                        .tint(viewModel.readerTextMutedColor)
                        .accessibilityLabel(String.localized("generic.search"))
                        .padding(.vertical, 16)
                } else if viewModel.hasNextSearchPageLoadError {
                    Button {
                        Task {
                            await viewModel.loadNextSearchPageIfNeeded()
                        }
                    } label: {
                        Label(String.localized("generic.error"), systemImage: "arrow.clockwise")
                    }
                    .foregroundStyle(viewModel.readerTextMutedColor)
                    .padding(.vertical, 16)
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
        let resultSetID = viewModel.searchResultSetID

        return Button {
            isSearchFieldFocused = false
            Task {
                // Allow keyboard dismissal to begin before closing the search sheet.
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
        .task(id: resultSetID) {
            await viewModel.loadVerseText(for: result, resultSetID: resultSetID)
        }
    }

    private func referenceTitle(for result: YouVersionVerseSearchResult) -> String {
        guard let reference = result.bibleReference(versionID: viewModel.reference.versionId) else {
            return result.reference
        }
        return viewModel.version?.displayTitle(for: reference, includesVersionAbbreviation: false) ?? result.reference
    }
}
