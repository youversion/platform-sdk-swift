import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderSearchView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchScrollPosition: String?
    @State private var showsSearchFilters = false

    var body: some View {
        VStack(spacing: 0) {
            BibleReaderSearchHeaderView(isSearchFieldFocused: $isSearchFieldFocused)
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
        .onChange(of: viewModel.searchRequestID) {
            searchScrollPosition = nil
        }
        .onChange(of: viewModel.searchCanonFilter) {
            searchScrollPosition = nil
        }
    }

    @ViewBuilder
    private var results: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            if viewModel.searchStatus == .searching || viewModel.isLoadingSearchQueries {
                ProgressView()
                    .controlSize(.small)
                    .tint(viewModel.readerTextMutedColor)
                    .accessibilityLabel(String.localized("generic.search"))
                    .padding(.vertical, 8)
            }

            if viewModel.searchStatus == .failed {
                searchStateView(
                    systemImage: "exclamationmark.circle",
                    title: String.localized("generic.error")
                )
            } else if viewModel.searchStatus == .completed
                        && viewModel.searchResults.isEmpty
                        && !viewModel.hasNextSearchPage {
                searchStateView(
                    systemImage: "magnifyingglass",
                    title: String.localized("noBibleSearchResults")
                )
            } else if viewModel.searchStatus == .completed {
                searchResultsHeader
                if viewModel.filteredSearchResults.isEmpty && !viewModel.hasNextSearchPage {
                    searchStateView(
                        systemImage: "magnifyingglass",
                        title: String.localized("noBibleSearchResults")
                    )
                } else {
                    searchResultsScrollView
                }
            } else {
                searchQueriesScrollView
            }
        }
    }

    private var searchQueriesScrollView: some View {
        let isSearchQueryBlank = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                searchQuerySection(
                    heading: String.localized("bibleSearchTrendingHeading"),
                    queries: isSearchQueryBlank ? viewModel.trendingSearchQueries.map(\.text) : [],
                    icon: Image("trending", bundle: .YouVersionUIBundle)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                )
                searchQuerySection(
                    heading: String.localized("bibleSearchRecentHeading"),
                    queries: isSearchQueryBlank ? viewModel.recentSearchQueries : [],
                    icon: Image(systemName: "clock.arrow.circlepath")
                        .font(.body)
                )
                searchQuerySection(
                    heading: nil,
                    queries: isSearchQueryBlank ? [] : viewModel.suggestedSearchQueries.map(\.text),
                    icon: Image(systemName: "magnifyingglass")
                        .font(.body)
                )
            }
            .frame(maxWidth: viewModel.readerMaxWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func searchQuerySection(heading: String?, queries: [String], icon: some View) -> some View {
        if !queries.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if let heading {
                    Text(heading)
                        .font(.headline)
                        .foregroundStyle(viewModel.readerTextPrimaryColor)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                }
                ForEach(Array(queries.enumerated()), id: \.offset) { _, query in
                    searchQueryButton(query, icon: icon)
                }
            }
        }
    }

    private func searchQueryButton(_ query: String, icon: some View) -> some View {
        Button {
            isSearchFieldFocused = false
            Task {
                await viewModel.search(for: query)
            }
        } label: {
            HStack(spacing: 12) {
                icon
                    .foregroundStyle(
                        viewModel.colorForScheme(
                            light: viewModel.readerTextPrimaryColor,
                            dark: viewModel.readerTextMutedColor
                        )
                    )
                    .frame(width: 36, height: 36)
                    .background(viewModel.readerSurfaceTertiaryColor, in: Circle())
                    .accessibilityHidden(true)
                Text(query)
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

    private var searchResultsScrollView: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            LazyVStack(spacing: 0) {
                let filteredResults = viewModel.filteredSearchResults
                ForEach(Array(filteredResults.enumerated()), id: \.element.passageId) { index, result in
                    resultButton(result)
                        .id(result.passageId)
                        .task(id: viewModel.nextSearchPageToken) {
                            let loadThreshold = max(0, filteredResults.count - 5)
                            guard index >= loadThreshold else {
                                return
                            }
                            await viewModel.loadNextSearchPageIfNeeded()
                        }
                }

                if filteredResults.isEmpty {
                    Color.clear
                        .frame(height: 1)
                        .task(id: viewModel.nextSearchPageToken) {
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
        .scrollPosition(id: $searchScrollPosition, anchor: .top)
    }

    private var searchResultsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String.localized("bibleSearchBibleHeading"))
                    .font(.headline)
                    .foregroundStyle(viewModel.readerTextPrimaryColor)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    showsSearchFilters.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Text(String.localized("bibleSearchFiltersButton"))
                        Image(systemName: "line.3.horizontal.decrease")
                            .scaleEffect(y: showsSearchFilters ? -1 : 1)
                            .accessibilityHidden(true)
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(viewModel.readerTextPrimaryColor)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(showsSearchFilters ? .isSelected : [])
            }

            if showsSearchFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SearchCanonFilter.allCases, id: \.self) { filter in
                            canonFilterChip(filter)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: viewModel.readerMaxWidth)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }

    private func canonFilterChip(_ filter: SearchCanonFilter) -> some View {
        let isSelected = filter == viewModel.searchCanonFilter

        return Button {
            viewModel.searchCanonFilter = filter
        } label: {
            Text(canonFilterTitle(filter))
                .font(.callout.weight(.semibold))
                .foregroundStyle(viewModel.readerTextPrimaryColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? viewModel.readerButtonSecondaryColor : .clear, in: Capsule())
                .overlay {
                    if !isSelected {
                        Capsule()
                            .strokeBorder(viewModel.readerBorderSecondaryColor, lineWidth: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func canonFilterTitle(_ filter: SearchCanonFilter) -> String {
        switch filter {
        case .oldTestament: String.localized("bibleSearchFilterOldTestament")
        case .newTestament: String.localized("bibleSearchFilterNewTestament")
        case .both: String.localized("bibleSearchFilterBoth")
        }
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

    private func resultButton(_ result: BibleReference) -> some View {
        let resultSetID = viewModel.searchRequestID

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
                    if let text = viewModel.searchResultTextByPassageID[result.passageId], !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    Text(viewModel.searchResultTitle(for: result))
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
            if let resultSetID {
                await viewModel.loadVerseText(for: result, resultSetID: resultSetID)
            }
        }
    }
}

private struct BibleReaderSearchHeaderView: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @FocusState.Binding var isSearchFieldFocused: Bool

    var body: some View {
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
}
