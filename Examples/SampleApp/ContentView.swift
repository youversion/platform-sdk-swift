import SwiftUI
import YouVersionPlatform

struct ContentView: View {
    let navigation: BibleReaderNavigation
    let onNavigate: () -> Void
    @State private var showsImages = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Content").font(.largeTitle.bold())
                    HStack(spacing: 0) {
                        Button { showsImages = false } label: {
                            Text("Videos")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(showsImages ? Color.secondary : Color(uiColor: .systemBackground))
                                .background(showsImages ? Color.clear : Color.primary, in: .capsule)
                        }
                        .accessibilityAddTraits(showsImages ? [] : .isSelected)
                        Button { showsImages = true } label: {
                            Text("Images")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(showsImages ? Color(uiColor: .systemBackground) : Color.secondary)
                                .background(showsImages ? Color.primary : Color.clear, in: .capsule)
                        }
                        .accessibilityAddTraits(showsImages ? .isSelected : [])
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .padding(3)
                    .background(.quaternary, in: .capsule)
                    .accessibilityIdentifier("content.type")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                ZStack {
                    ContentCollectionsView()
                        .opacity(showsImages ? 0 : 1)
                        .allowsHitTesting(!showsImages)
                        .accessibilityHidden(showsImages)
                    ContentImagesView(navigation: navigation, onNavigate: onNavigate)
                        .opacity(showsImages ? 1 : 0)
                        .allowsHitTesting(showsImages)
                        .accessibilityHidden(!showsImages)
                }
            }
            .navigationTitle(showsImages ? "Images" : "Videos")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
