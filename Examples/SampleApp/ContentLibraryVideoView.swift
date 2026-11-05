import AVKit
import SwiftUI
import YouVersionPlatform

struct ContentLibraryVideoView: View {
    let video: YouVersionVideo
    @State private var player: AVPlayer?
    @State private var playbackError: String?
    @State private var retryID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let playbackError {
                ContentUnavailableView {
                    Label("Video unavailable", systemImage: "video.slash")
                } description: {
                    Text(playbackError)
                } actions: {
                    Button("Retry") { retryID = UUID() }
                        .accessibilityIdentifier("library.retryPlayback")
                }
            } else if playbackURL != nil {
                VideoPlayer(player: player)
                    .aspectRatio(video.displayAspectRatio, contentMode: .fit)
                    .accessibilityIdentifier("library.videoPlayer")
            } else {
                ContentUnavailableView("Video unavailable", systemImage: "video.slash")
            }
            if let title = video.title {
                Text(title).font(.title2.bold())
            }
            if let description = video.description {
                Text(description).font(.body)
            }
            Spacer()
        }
        .padding()
        .navigationTitle(video.title ?? "Video")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: PlaybackRequest(url: playbackURL, retryID: retryID)) {
            guard let playbackURL else {
                return
            }
            playbackError = nil
            if player == nil { player = AVPlayer() }
            guard let player else {
                return
            }
            if (player.currentItem?.asset as? AVURLAsset)?.url != playbackURL || player.currentItem?.status == .failed {
                player.replaceCurrentItem(with: AVPlayerItem(url: playbackURL))
            }
            player.play()
            if let item = player.currentItem {
                await observeFailure(of: item)
            }
        }
        .onDisappear { player?.pause() }
    }

    private struct PlaybackRequest: Equatable {
        let url: URL?
        let retryID: UUID
    }

    private var playbackURL: URL? {
        (video.playbackSources.first(where: { $0.format == "hls" })
            ?? video.playbackSources.first(where: { $0.format == "mp4" }))?.url
    }

    private func observeFailure(of item: AVPlayerItem) async {
        let (statuses, continuation) = AsyncStream<AVPlayerItem.Status>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let observation = item.observe(\.status, options: [.initial, .new]) { item, _ in
            continuation.yield(item.status)
        }
        defer {
            observation.invalidate()
            continuation.finish()
        }
        for await status in statuses {
            guard !Task.isCancelled && player?.currentItem === item else {
                return
            }
            if status == .failed {
                playbackError = item.error?.localizedDescription ?? String(localized: "Video unavailable")
                return
            }
        }
    }
}

extension YouVersionVideo {
    /// Uses thumbnail dimensions when available, with a presentation-only fallback for missing metadata.
    var displayAspectRatio: Double {
        thumbnail?.aspectRatio ?? (orientation == "portrait" ? 9.0 / 16 : 16.0 / 9)
    }
}
