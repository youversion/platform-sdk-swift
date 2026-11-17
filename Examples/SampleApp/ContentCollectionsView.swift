import SwiftUI
import YouVersionPlatform

struct ContentCollectionsView: View {
    let language: ContentLanguage
    @State private var collections: [YouVersionVideoPlaylist] = []
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var retryID = UUID()

    private let organizationID = "6a4552c4-96eb-4df9-aa89-b2cae8db310d"

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let errorMessage {
                    ContentUnavailableView {
                        Label("Unable to load collections", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") { retryID = UUID() }
                    }
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if collections.isEmpty {
                    ContentUnavailableView("No collections available", systemImage: "play.rectangle")
                } else {
                    if let featured = collections.first {
                        Text("Featured").font(.title3.bold())
                        NavigationLink {
                            ContentCollectionView(collection: featured, language: language)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ContentCollectionThumbnailView(videoID: featured.videoIDs?.first, language: language, showsPlayIndicator: true)
                                Text(featured.title ?? "Collection").font(.headline)
                                if let total = featured.total {
                                    Text("\(total) videos").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Text("All collections").font(.title3.bold())
                    ForEach(collections, id: \.id) { collection in
                        NavigationLink {
                            ContentCollectionView(collection: collection, language: language)
                        } label: {
                            HStack(spacing: 12) {
                                ContentCollectionThumbnailView(videoID: collection.videoIDs?.first, language: language)
                                    .frame(width: 112, height: 64)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(collection.title ?? "Collection").font(.headline)
                                    if let total = collection.total {
                                        Text("\(total) videos").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .task(id: retryID) { await loadCollections() }
    }

    private func loadCollections() async {
        guard collections.isEmpty else {
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            var loaded: [YouVersionVideoPlaylist] = []
            var pageToken: String?
            var visitedTokens: Set<String> = []
            repeat {
                if let pageToken {
                    guard visitedTokens.insert(pageToken).inserted else {
                        throw YouVersionAPIError.invalidResponse
                    }
                }
                let page = try await YouVersionAPI.Videos.playlists(organizationID: organizationID, pageSize: "99", pageToken: pageToken, session: language.videoSession)
                try Task.checkCancellation()
                loaded += page.playlists
                pageToken = page.nextPageToken
            } while pageToken != nil
            collections = loaded.sorted { ($0.title ?? "").localizedStandardCompare($1.title ?? "") == .orderedAscending }
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}

struct ContentVideoThumbnailView: View {
    let videoID: String?
    let language: ContentLanguage
    var showsPlayIndicator = false
    var video: YouVersionVideo?
    @State private var loadedVideo: YouVersionVideo?
    @State private var errorMessage: String?
    @State private var retryID = UUID()

    var body: some View {
        Group {
            if let errorMessage {
                Button { retryID = UUID() } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Retry loading thumbnail")
                .accessibilityHint(errorMessage)
            } else {
                AsyncImage(url: (video ?? loadedVideo)?.thumbnail?.url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                            .overlay(alignment: .bottomLeading) {
                                if showsPlayIndicator {
                                    Image(systemName: "play.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                        .padding(12)
                                        .accessibilityHidden(true)
                                }
                            }
                    } else if phase.error != nil {
                        Button { retryID = UUID() } label: {
                            Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Retry loading thumbnail")
                    } else if video == nil && loadedVideo == nil && videoID != nil {
                        ProgressView()
                    } else {
                        Image(systemName: "play.fill").foregroundStyle(.secondary)
                    }
                }
                .id(retryID)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .task(id: retryID) {
            guard let videoID, video == nil && loadedVideo == nil else {
                return
            }
            errorMessage = nil
            do {
                let resolved = try await YouVersionAPI.Videos.video(id: videoID, size: "card", session: language.videoSession)
                try Task.checkCancellation()
                loadedVideo = resolved
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }
}

private struct ContentCollectionThumbnailView: View {
    let videoID: String?
    let language: ContentLanguage
    var showsPlayIndicator = false

    var body: some View {
        ContentVideoThumbnailView(videoID: videoID, language: language, showsPlayIndicator: showsPlayIndicator)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .padding(.horizontal, 10)
                    .offset(y: -5)
            }
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .quaternarySystemFill))
                    .padding(.horizontal, 18)
                    .offset(y: -10)
            }
            .padding(.top, 10)
    }
}
