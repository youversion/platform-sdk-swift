import SwiftUI
import YouVersionPlatform

struct ContentCollectionsView: View {
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
                            ContentCollectionView(collection: featured)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ContentCollectionThumbnailView(videoID: featured.videoIDs?.first)
                                    .aspectRatio(16.0 / 9, contentMode: .fit)
                                Text(featured.title ?? "Collection").font(.headline)
                                if let total = featured.total {
                                    Text("\(total) videos").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Text("All collections").font(.title3.bold())
                    ForEach(collections) { collection in
                        NavigationLink {
                            ContentCollectionView(collection: collection)
                        } label: {
                            HStack(spacing: 12) {
                                ContentCollectionThumbnailView(videoID: collection.videoIDs?.first)
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
            repeat {
                let page = try await YouVersionAPI.Videos.playlists(organizationID: organizationID, pageSize: "99", pageToken: pageToken)
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
    @State private var video: YouVersionVideo?
    @State private var errorMessage: String?
    @State private var retryID = UUID()

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            if let errorMessage {
                Button { retryID = UUID() } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Retry loading thumbnail")
                .accessibilityHint(errorMessage)
            } else {
                AsyncImage(url: video?.thumbnail?.url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        Button { retryID = UUID() } label: {
                            Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Retry loading thumbnail")
                    } else if video == nil && videoID != nil {
                        ProgressView()
                    } else {
                        Image(systemName: "play.fill").foregroundStyle(.secondary)
                    }
                }
                .id(retryID)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
        .task(id: retryID) {
            guard let videoID, video == nil else {
                return
            }
            errorMessage = nil
            do {
                let resolved = try await YouVersionAPI.Videos.video(id: videoID, size: "card")
                try Task.checkCancellation()
                video = resolved
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }
}

private struct ContentCollectionThumbnailView: View {
    let videoID: String?

    var body: some View {
        ContentVideoThumbnailView(videoID: videoID)
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
