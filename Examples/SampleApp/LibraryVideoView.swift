import AVKit
import SwiftUI
import YouVersionPlatform

struct LibraryVideoView: View {
    let video: YouVersionVideo
    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if playbackURL != nil {
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
        .task(id: playbackURL) {
            guard let playbackURL else {
                return
            }
            if player == nil { player = AVPlayer() }
            player?.replaceCurrentItem(with: AVPlayerItem(url: playbackURL))
            player?.play()
        }
        .onDisappear { player?.pause() }
    }

    private var playbackURL: URL? {
        (video.playbackSources.first(where: { $0.format == "hls" })
            ?? video.playbackSources.first(where: { $0.format == "mp4" }))?.url
    }
}

extension YouVersionVideo {
    /// Uses thumbnail dimensions when available, with a presentation-only fallback for missing metadata.
    var displayAspectRatio: Double {
        thumbnail?.aspectRatio ?? (orientation == "portrait" ? 9.0 / 16 : 16.0 / 9)
    }
}
