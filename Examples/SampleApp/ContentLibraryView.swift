import SwiftUI

struct ContentLibraryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Content Library")
                        .font(.largeTitle.bold())
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    BibleProjectLibraryView()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Content Library")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
