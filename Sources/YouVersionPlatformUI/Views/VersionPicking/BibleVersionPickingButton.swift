import SwiftUI
import YouVersionPlatformCore

public struct BibleVersionPickingButton: View {
    @State private var versionsViewModel: BibleVersionsViewModel
    private let initialVersionId: Int
    private let onVersionChange: ((BibleVersion) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    public init(
        initialVersionId: Int,
        onVersionChange: ((BibleVersion) -> Void)? = nil
    ) {
        self.initialVersionId = initialVersionId
        self._versionsViewModel = State(wrappedValue: BibleVersionsViewModel())
        self.onVersionChange = onVersionChange
    }

    public var body: some View {
        @Bindable var bindableVersionsViewModel = versionsViewModel
        let version = versionsViewModel.currentVersion

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
            await versionsViewModel.loadInitialState(initialVersionId: initialVersionId)
        }
        .onChange(of: versionsViewModel.currentVersion) { _, newVersion in
            if let newVersion {
                onVersionChange?(newVersion)
            }
        }
        .onChange(of: colorScheme, initial: true) { _, newScheme in
            versionsViewModel.colorTheme = ReaderTheme(
                id: 0,
                foreground: newScheme == .dark ? Color(hex: "#ffffff") : Color(hex: "#121212"),
                background: newScheme == .dark ? Color(hex: "#121212") : Color(hex: "#ffffff"),
                colorScheme: newScheme
            )
        }
    }
}

#Preview {
    BibleVersionPickingButton(initialVersionId: 3034)
}
