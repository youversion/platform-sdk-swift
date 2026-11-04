import SwiftUI
import YouVersionPlatform

struct MoreView: View {
    let navigation: BibleReaderNavigation
    let onNavigate: () -> Void

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    NavigateView(navigation: navigation, onNavigate: onNavigate)
                } label: {
                    Label("tab.navigate", systemImage: "arrow.uturn.right")
                }

                NavigationLink {
                    VotdContainerView()
                        .navigationTitle("tab.votd")
                } label: {
                    Label("tab.votd", systemImage: "sun.max.fill")
                }

                NavigationLink {
                    CardView()
                        .navigationTitle("tab.card")
                } label: {
                    Label("tab.card", systemImage: "doc.plaintext")
                }
            }
            .navigationTitle("More")
        }
    }
}
