import SwiftUI
import YouVersionPlatformCore

struct VotdImageView: View {
    let image: YouVersionImage
    let onAdvance: (() -> Void)?

    @State private var retryCount = 0

    init(image: YouVersionImage, onAdvance: (() -> Void)? = nil) {
        self.image = image
        self.onAdvance = onAdvance
    }

    /// Requests the API's `card` rendition for this example, preserving the URL's other query parameters.
    /// Choose `thumb`, `card`, or `full` to suit your app's image size needs, or omit `size` for full size.
    private var renditionURL: URL? {
        var components = URLComponents(url: image.imageURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems?.filter { $0.name != "size" } ?? []
        components?.queryItems = queryItems + [URLQueryItem(name: "size", value: "card")]
        return components?.url
    }

    var body: some View {
        AsyncImage(url: renditionURL) { phase in
            switch phase {
            case .success(let artwork):
                if onAdvance == nil {
                    artwork.resizable().scaledToFit()
                } else {
                    Button {
                        onAdvance?()
                    } label: {
                        artwork.resizable().scaledToFit()
                    }
                    .buttonStyle(VotdImageButtonStyle())
                }
            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("Image couldn't load")
                        .font(.callout)
                    Button("Retry image") { retryCount += 1 }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .id(retryCount)
        .aspectRatio(CGFloat(max(image.width, 1)) / CGFloat(max(image.height, 1)), contentMode: .fit)
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
