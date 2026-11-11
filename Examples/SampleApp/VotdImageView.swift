import SwiftUI
import YouVersionPlatformCore

/// Displays a supplied verse image with loading and retry states, preserving its aspect ratio.
/// Use decorative presentation for passive previews without loading or error controls.
/// Use it on its own, or provide `onImageTap` to handle taps when browsing several images.
struct VotdImageView: View {
    enum Presentation: Equatable {
        case standard, decorative
    }
    
    let image: YouVersionImage
    private let presentation: Presentation
    let onImageTap: (() -> Void)?
    
    @State private var retryCount = 0
    
    init(image: YouVersionImage, presentation: Presentation = .standard, onImageTap: (() -> Void)? = nil) {
        self.image = image
        self.presentation = presentation
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
                if presentation == .decorative {
                    Color.clear
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                        Text("votd.image_load_failed")
                            .font(.callout)
                        Button("votd.retry_image") { retryCount += 1 }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
                }
            default:
                if presentation == .decorative {
                    Color.clear
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                }
            }
        }
        .id(retryCount)
        .aspectRatio(CGFloat(image.aspectRatio), contentMode: .fit)
        .background(.quaternary)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 18))
        .allowsHitTesting(presentation == .standard)
        .accessibilityHidden(presentation == .decorative)
        .transaction { transaction in transaction.animation = nil }
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
