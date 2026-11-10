import SwiftUI
import YouVersionPlatform

struct ContentCollectionView: View {
    let collection: YouVersionVideoPlaylist
    @State private var videos: [YouVersionVideo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var retryID = UUID()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let first = videos.first {
                    NavigationLink {
                        ContentVideoView(video: first)
                    } label: {
                        ContentVideoThumbnailView(videoID: first.id)
                            .aspectRatio(16.0 / 9, contentMode: .fit)
                            .overlay { Image(systemName: "play.circle.fill").font(.largeTitle).foregroundStyle(.white) }
                    }
                    .accessibilityLabel("Play \(first.title ?? "video")")
                } else {
                    ContentVideoThumbnailView(videoID: collection.videoIDs?.first)
                        .aspectRatio(16.0 / 9, contentMode: .fit)
                }
                Text(collection.title ?? "Collection").font(.title2.bold())
                HStack(alignment: .top, spacing: 12) {
                    if let total = collection.total {
                        ContentMetadataView(title: "Videos", value: String(total))
                    }
                    if let duration {
                        ContentMetadataView(title: "Duration", value: duration)
                    }
                    if !languages.isEmpty {
                        ContentMetadataView(title: "Language", value: languages.joined(separator: ", "))
                    }
                }
                Divider()
                Text("Videos").font(.title3.bold())
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                    Button("Retry") { retryID = UUID() }
                }
                ForEach(videos, id: \.id) { video in
                    NavigationLink {
                        ContentVideoView(video: video)
                    } label: {
                        HStack(spacing: 12) {
                            ContentVideoThumbnailView(videoID: video.id)
                                .frame(width: 108, height: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.title ?? "Video").font(.headline)
                                if let runtime = video.runtime {
                                    Text(Duration.seconds(runtime).formatted(.time(pattern: .minuteSecond)))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: ([collection.title].compactMap { $0 } + videos.compactMap { $0.shareURL?.absoluteString }).joined(separator: "\n"))
        }
        .task(id: retryID) { await loadVideos() }
    }

    private var duration: String? {
        guard !videos.isEmpty && videos.count == collection.videoIDs?.count && videos.allSatisfy({ $0.runtime != nil }) else {
            return nil
        }
        return Duration.seconds(videos.reduce(0) { $0 + ($1.runtime ?? 0) }).formatted(.time(pattern: .hourMinuteSecond))
    }

    private var languages: [String] {
        Set(videos.compactMap(\.languageTag)).sorted().map { Locale.current.localizedString(forIdentifier: $0) ?? $0 }
    }

    private func loadVideos() async {
        let loadedIDs = Set(videos.map(\.id))
        let pendingIDs = (collection.videoIDs ?? []).filter { !loadedIDs.contains($0) }
        guard !pendingIDs.isEmpty else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let results = await withTaskGroup(of: (YouVersionVideo?, String?).self) { group in
            for id in pendingIDs {
                group.addTask {
                    do {
                        return (try await YouVersionAPI.Videos.video(id: id, size: "card"), nil)
                    } catch {
                        return (nil, error.localizedDescription)
                    }
                }
            }
            return await group.reduce(into: [(YouVersionVideo?, String?)]()) { $0.append($1) }
        }
        guard !Task.isCancelled else {
            return
        }
        let resolved = videos + results.compactMap(\.0)
        videos = (collection.videoIDs ?? []).compactMap { id in resolved.first { $0.id == id } }
        errorMessage = results.compactMap(\.1).first
    }
}

private struct ContentMetadataView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: .rect(cornerRadius: 10))
    }
}
