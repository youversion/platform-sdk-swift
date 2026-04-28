import SwiftUI
import YouVersionPlatformCore

public struct BibleVersionPickingButton: View {
    @State private var versionsViewModel: BibleVersionsViewModel
    @State private var version: BibleVersion?
    private let initialVersionId: Int
    private let onVersionChange: ((BibleVersion) -> Void)?

    public init(
        initialVersionId: Int,
        onVersionChange: ((BibleVersion) -> Void)? = nil
    ) {
        self.initialVersionId = initialVersionId
        self._versionsViewModel = State(wrappedValue: BibleVersionsViewModel { _ in })
        self.onVersionChange = onVersionChange
    }

    public var body: some View {
        @Bindable var bindableVersionsViewModel = versionsViewModel

        Button {
            versionsViewModel.openVersionsStack(currentBibleLanguage: version?.languageTag ?? "en")
        } label: {
            Text(version?.localizedAbbreviation ?? version?.abbreviation ?? " ")
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
    }

    private func handleVersionChange(_ version: BibleVersion) {
        self.version = version
        onVersionChange?(version)
    }
}

#Preview {
    BibleVersionPickingButton(initialVersionId: 3034)
}
