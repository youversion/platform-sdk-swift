import SwiftUI
import YouVersionPlatformCore

/// Displays a supplied verse image with loading and retry states, preserving its aspect ratio.
/// Use it on its own, or provide `onImageTap` to handle taps when browsing several images.
struct VotdImageView: View {
    let image: YouVersionImage
    let onImageTap: (() -> Void)?

    @State private var retryCount = 0

    init(image: YouVersionImage, onImageTap: (() -> Void)? = nil) {
        self.image = image
        self.onImageTap = onImageTap
    }

    var body: some View {
        AsyncImage(url: image.url) { phase in
            switch phase {
            case .success(let artwork):
                if onImageTap == nil {
                    artwork.resizable().scaledToFit()
                } else {
                    Button {
                        onImageTap?()
                    } label: {
                        artwork.resizable().scaledToFit()
                    }
                    .buttonStyle(VotdImageButtonStyle())
                }
            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("votd.image_load_failed")
                        .font(.callout)
                    Button("votd.retry_image") { retryCount += 1 }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .id(retryCount)
        .aspectRatio(CGFloat(image.aspectRatio), contentMode: .fit)
        .background(.quaternary)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 18))
    }
}

private struct VotdImageButtonStyle: PrimitiveButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect)
            .onTapGesture {
                if isEnabled {
                    configuration.trigger()
                }
            }
    }
}
