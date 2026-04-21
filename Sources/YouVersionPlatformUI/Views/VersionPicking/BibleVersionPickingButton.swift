import SwiftUI
import YouVersionPlatformCore

public struct BibleVersionPickingButton: View {
    @State private var versionsViewModel: BibleVersionsViewModel
    @State private var currentVersionId: Int
    @State private var currentVersionAbbreviation: String?
    private let initialVersionId: Int
    private let onVersionChange: ((BibleVersion) -> Void)?

    public init(
        initialVersionId: Int,
        onVersionChange: ((BibleVersion) -> Void)? = nil
    ) {
        self.initialVersionId = initialVersionId
        self.currentVersionId = initialVersionId
        self.versionsViewModel = BibleVersionsViewModel { _ in }
        self.onVersionChange = onVersionChange
    }

    public var body: some View {
        @Bindable var bindableVersionsViewModel = versionsViewModel

        Button {
            versionsViewModel.openVersionsStack(currentBibleLanguage: versionsViewModel.currentBibleVersionLanguage ?? "en")
        } label: {
            Text(currentVersionAbbreviation ?? " ")
                .font(.system(size: 14, weight: .semibold))
                .frame(minWidth: 30)
        }
        .foregroundStyle(Color.primary)
        .buttonStyle(.bordered)
        .sheet(isPresented: $bindableVersionsViewModel.showingVersionsStack) {
            BibleVersionsStack()
                .environment(versionsViewModel)
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .task {
            versionsViewModel.onVersionChange = handleVersionChange
            await versionsViewModel.loadInitialState(initialVersionId: initialVersionId)
        }
        .onChange(of: currentVersionId, initial: true) { _, newVersionId in
            Task {
                let captured = newVersionId
                if let version = try? await BibleVersionRepository.shared.version(withId: captured) {
                    guard currentVersionId == captured else { return }
                    self.currentVersionAbbreviation = version.localizedAbbreviation ?? "\(captured)"
                }
            }
        }
    }

    private func handleVersionChange(_ version: BibleVersion) {
        currentVersionId = version.id
        versionsViewModel.currentBibleVersionLanguage = version.languageTag
        onVersionChange?(version)
    }
}

#Preview {
    BibleVersionPickingButton(initialVersionId: 3034)
}
