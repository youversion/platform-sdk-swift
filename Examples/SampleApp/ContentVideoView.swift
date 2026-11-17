import AVFAudio
import AVKit
import SwiftUI
import YouVersionPlatform

struct ContentVideoView: View {
    let video: YouVersionVideo
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var player: AVPlayer?
    @State private var playbackError: String?
    @State private var retryID = UUID()
    @State private var isPlaying = false
    @State private var isFullScreen = false
    @State private var hasDismissedFullScreen = false
    @State private var shouldResumePlayback = false

    var body: some View {
        ScrollView {
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
                    Text(title).font(.title2.bold()).padding(.horizontal, 20)
                }
                if let description = video.description {
                    Text(description).font(.body).padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if let shareURL = video.shareURL {
                ShareLink(item: shareURL)
            }
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                VideoPlayer(player: player)
                Button(String(localized: "Close"), systemImage: "xmark") {
                    hasDismissedFullScreen = true
                    isFullScreen = false
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .padding()
                .tint(.white)
                .accessibilityIdentifier("library.closeFullScreenVideo")
            }
            .statusBarHidden()
            .accessibilityAction(.escape) {
                hasDismissedFullScreen = true
                isFullScreen = false
            }
        }
        .onChange(of: verticalSizeClass) { _, sizeClass in
            if sizeClass == .compact && isPlaying {
                isFullScreen = true
            } else if sizeClass != .compact {
                hasDismissedFullScreen = false
                isFullScreen = false
            }
        }
        .onChange(of: isPlaying) { _, isPlaying in
            if isPlaying && verticalSizeClass == .compact && !hasDismissedFullScreen {
                isFullScreen = true
            }
        }
        .onChange(of: playbackError) { _, error in
            if error != nil {
                isFullScreen = false
            }
        }
        .task(id: player) {
            if let player {
                await observePlayback(of: player)
            }
        }
        .task(id: retryID) {
            guard let playbackURL else {
                return
            }
            playbackError = nil
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                playbackError = error.localizedDescription
                return
            }
            if player == nil { player = AVPlayer() }
            guard let player else {
                return
            }
            if (player.currentItem?.asset as? AVURLAsset)?.url != playbackURL || player.currentItem?.status == .failed {
                player.replaceCurrentItem(with: AVPlayerItem(url: playbackURL))
                shouldResumePlayback = true
            }
            if shouldResumePlayback {
                shouldResumePlayback = false
                player.play()
            }
            if let item = player.currentItem {
                await observeFailure(of: item)
            }
        }
        .onDisappear {
            guard !isFullScreen else {
                return
            }
            shouldResumePlayback = player?.timeControlStatus == .playing || player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
            player?.pause()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private var playbackURL: URL? {
        (video.playbackSources.first(where: { $0.format == "hls" })
            ?? video.playbackSources.first(where: { $0.format == "mp4" }))?.url
    }

    private func observePlayback(of player: AVPlayer) async {
        let (statuses, continuation) = AsyncStream<AVPlayer.TimeControlStatus>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let observation = player.observe(\.timeControlStatus, options: [.initial, .new]) { player, _ in
            continuation.yield(player.timeControlStatus)
        }
        defer {
            observation.invalidate()
            continuation.finish()
        }
        for await status in statuses {
            guard !Task.isCancelled else {
                return
            }
            isPlaying = status == .playing
        }
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
