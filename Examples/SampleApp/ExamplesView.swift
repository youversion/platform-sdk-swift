import SwiftUI
import YouVersionPlatform

struct ExamplesView: View {
    let navigation: BibleReaderNavigation
    let onNavigate: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Examples")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                List {
                    NavigationLink {
                        NavigateView(navigation: navigation, onNavigate: onNavigate)
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        Label {
                            Text("tab.navigate")
                        } icon: {
                            Image(systemName: "arrow.uturn.right").foregroundStyle(.black)
                        }
                    }
                    .listRowBackground(Color(uiColor: .systemGroupedBackground))

                    NavigationLink {
                        VotdContainerView()
                            .navigationTitle("tab.votd")
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        Label {
                            Text("tab.votd")
                        } icon: {
                            Image(systemName: "sun.max.fill").foregroundStyle(.black)
                        }
                    }
                    .listRowBackground(Color(uiColor: .systemGroupedBackground))

                    NavigationLink {
                        CardView()
                            .navigationTitle("tab.card")
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        Label {
                            Text("tab.card")
                        } icon: {
                            Image(systemName: "doc.plaintext").foregroundStyle(.black)
                        }
                    }
                    .listRowBackground(Color(uiColor: .systemGroupedBackground))
                }
                .scrollContentBackground(.hidden)
                .padding(.top, 16)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Examples")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
