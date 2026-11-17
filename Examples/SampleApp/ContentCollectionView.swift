import SwiftUI
import YouVersionPlatform

struct ContentCollectionView: View {
    let collection: YouVersionVideoPlaylist
    let language: ContentLanguage
    @Environment(\.locale) private var locale
    @State private var videosByRequestedID: [String: YouVersionVideo] = [:]
    @State private var activeLoadID: UUID?
    @State private var errorMessage: String?
    @State private var retryID = UUID()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let first = videos.first {
                    NavigationLink {
                        ContentVideoView(video: first, collectionTitle: collection.title)
                    } label: {
                        ContentVideoThumbnailView(videoID: first.id, language: language)
                            .aspectRatio(16.0 / 9, contentMode: .fit)
                            .overlay(alignment: .bottomLeading) {
                                Image(systemName: "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                                    .padding(12)
                                    .accessibilityHidden(true)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if let runtime = first.runtime {
                                    ContentVideoDurationView(runtime: runtime)
                                        .padding(12)
                                }
                            }
                    }
                    .accessibilityLabel("Play \(first.title ?? "video")")
                } else {
                    ContentVideoThumbnailView(videoID: collection.videoIDs?.first, language: language)
                        .aspectRatio(16.0 / 9, contentMode: .fit)
                }
                Text(collection.title ?? "Collection").font(.title2.bold())
                if let description = collection.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
                        ContentVideoView(video: video, collectionTitle: collection.title)
                    } label: {
                        HStack(spacing: 12) {
                            ContentVideoThumbnailView(videoID: video.id, language: language)
                                .frame(width: 108, height: 64)
                                .overlay(alignment: .bottomTrailing) {
                                    if let runtime = video.runtime {
                                        ContentVideoDurationView(runtime: runtime)
                                            .padding(6)
                                    }
                                }
                            Text(video.title ?? "Video").font(.headline)
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

    private var isLoading: Bool {
        activeLoadID != nil
    }

    private var videos: [YouVersionVideo] {
        (collection.videoIDs ?? []).compactMap { videosByRequestedID[$0] }
    }

    private var duration: String? {
        guard !videos.isEmpty && videos.count == collection.videoIDs?.count && videos.allSatisfy({ $0.runtime != nil }) else {
            return nil
        }
        return Duration.seconds(videos.reduce(0) { $0 + ($1.runtime ?? 0) }).formatted(.time(pattern: .hourMinuteSecond))
    }

    private var languages: [String] {
        Set(videos.compactMap(\.languageTag)).sorted().map { locale.localizedString(forIdentifier: $0) ?? $0 }
    }

    private func loadVideos() async {
        guard !Task.isCancelled else {
            return
        }
        let loadID = UUID()
        activeLoadID = loadID
        defer {
            if activeLoadID == loadID { activeLoadID = nil }
        }
        let pendingIDs = (collection.videoIDs ?? []).filter { videosByRequestedID[$0] == nil }
        guard !pendingIDs.isEmpty else {
            return
        }
        errorMessage = nil
        let results = await withTaskGroup(of: (String, YouVersionVideo?, String?).self) { group in
            for id in pendingIDs {
                group.addTask {
                    do {
                        return (id, try await YouVersionAPI.Videos.video(id: id, size: "card", session: language.videoSession), nil)
                    } catch {
                        return (id, nil, error.localizedDescription)
                    }
                }
            }
            return await group.reduce(into: [(String, YouVersionVideo?, String?)]()) { $0.append($1) }
        }
        guard !Task.isCancelled && activeLoadID == loadID else {
            return
        }
        videosByRequestedID = results.reduce(into: videosByRequestedID) { resolved, result in
            if let video = result.1 {
                resolved[result.0] = video
            }
        }
        errorMessage = results.compactMap(\.2).first
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

private struct ContentVideoDurationView: View {
    let runtime: Int

    var body: some View {
        Text(Duration.seconds(runtime).formatted(.time(pattern: runtime >= 3600 ? .hourMinuteSecond : .minuteSecond)))
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.8), in: .capsule)
    }
}
