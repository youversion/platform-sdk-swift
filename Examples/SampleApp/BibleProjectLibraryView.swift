import SwiftUI
import YouVersionPlatform

struct BibleProjectLibraryView: View {
    @State private var playlists: [YouVersionVideoPlaylist] = []
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var retryID = UUID()

    private let organizationID = "6a4552c4-96eb-4df9-aa89-b2cae8db310d"

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            Text(verbatim: "BibleProject")
                .font(.title.bold())
                .padding(.horizontal, 20)
            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage).foregroundStyle(.secondary)
                    Button("Retry") { retryID = UUID() }
                        .accessibilityIdentifier("library.retryPlaylists")
                }
                .padding(.horizontal, 20)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if playlists.isEmpty {
                Text("No videos available.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            ForEach(playlists) { playlist in
                VideoPlaylistView(playlist: playlist)
            }
        }
        .task(id: retryID) {
            guard playlists.isEmpty else {
                return
            }
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                var loadedPlaylists: [YouVersionVideoPlaylist] = []
                var pageToken: String?
                repeat {
                    let page = try await YouVersionAPI.Videos.playlists(organizationID: organizationID, pageSize: 99, pageToken: pageToken)
                    try Task.checkCancellation()
                    loadedPlaylists += page.playlists
                    pageToken = page.playlists.isEmpty ? nil : page.nextPageToken
                } while pageToken != nil
                playlists = loadedPlaylists
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }
}

private struct VideoPlaylistView: View {
    let playlist: YouVersionVideoPlaylist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(playlist.title)
                .font(.headline)
                .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(playlist.videoIDs, id: \.self) { videoID in
                        VideoThumbnailView(videoID: videoID)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .frame(height: 56)
        }
    }
}

private struct VideoThumbnailView: View {
    let videoID: String
    @Environment(\.displayScale) private var displayScale
    @State private var video: YouVersionVideo?
    @State private var errorMessage: String?
    @State private var retryID = UUID()

    var body: some View {
        Group {
            if let video {
                let width = 56 * video.displayAspectRatio
                NavigationLink {
                    ContentLibraryVideoView(video: video)
                } label: {
                    let url = video.thumbnail?.url(width: Int((width * displayScale).rounded(.up)), height: Int(56 * displayScale))
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else if url == nil || phase.error != nil {
                            Image(systemName: "photo")
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: width, height: 56)
                    .clipShape(.rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(video.title ?? "Video")
                .accessibilityIdentifier("library.video.\(videoID)")
            } else if let errorMessage {
                Button { retryID = UUID() } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(width: 100, height: 56)
                }
                .accessibilityLabel("Retry loading video")
                .accessibilityHint(errorMessage)
                .accessibilityIdentifier("library.retryVideoMetadata.\(videoID)")
            } else {
                ProgressView().frame(width: 100, height: 56)
            }
        }
        .task(id: retryID) {
            guard video == nil else {
                return
            }
            errorMessage = nil
            do {
                let resolved = try await YouVersionAPI.Videos.video(id: videoID)
                try Task.checkCancellation()
                video = resolved
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }
}
