import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderNotesDrawer: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Bindable var draft: BibleReaderNoteDraft
    @FocusState private var isEditing: Bool
    @State private var contentHeight: CGFloat = 240
#if !os(tvOS)
    @State private var contextProvider = ReaderAuthenticationContextProvider()
#endif

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                NoteHeader(draft: draft)
                TextField(NoteStrings.placeholder, text: $draft.content, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.body)
                    .padding(12)
                    .background(viewModel.readerSurfaceTertiaryColor, in: RoundedRectangle(cornerRadius: 8))
                    .focused($isEditing)
                    .accessibilityIdentifier("notes.content")
                    .disabled(draft.isSaving)
                ScrollView(.horizontal, showsIndicators: false) {
                    BibleReaderHighlightColors(
                        selectedHexes: draft.colorHex.map { [$0] } ?? [],
                        availableHexes: BibleReaderHighlightColors.palette.filter { $0 != draft.colorHex },
                        hasBackground: false,
                        onRemove: { _ in draft.colorHex = nil },
                        onAdd: { draft.colorHex = $0 }
                    )
                }
                .frame(height: 55)
                .disabled(draft.isSaving)
                cancelAndSaveButtons
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .presentationDetents([.height(contentHeight), .large])
        .modifier(BibleReaderNoteDismissalModifier(draft: draft))
        .alert(NoteStrings.discardTitle, isPresented: $draft.showingDiscardConfirmation) {
            Button(NoteStrings.discard, role: .destructive) { viewModel.discardNote() }
            Button(String.localized("generic.cancel"), role: .cancel) { }
        } message: {
            Text(NoteStrings.discardMessage)
        }
        .alert(String.localized("generic.error"), isPresented: $draft.showingSaveError) {
            Button(String.localized("generic.ok"), role: .cancel) { }
        } message: {
            Text(String.localized("generic.requestErrorBody"))
        }
    }

    private var cancelAndSaveButtons: some View {
        HStack {
            Button(String.localized("generic.cancel")) { viewModel.requestDismissNote() }
                .frame(minWidth: 44, minHeight: 44)
                .disabled(draft.isSaving)
            Spacer()
            Button {
                Task {
                    if await draft.save(authorize: authorize) {
                        isEditing = false
                        viewModel.finishNote(draft)
                    }
                }
            } label: {
                HStack {
                    if draft.isSaving { ProgressView().tint(viewModel.readerCanvasPrimaryColor) }
                    Text(NoteStrings.save)
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .foregroundStyle(viewModel.readerCanvasPrimaryColor)
                .background(viewModel.readerTextPrimaryColor, in: Capsule())
                .opacity(draft.canSave ? 1 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(!draft.canSave)
            .accessibilityIdentifier("notes.submit")
        }
    }

    private func authorize() async throws {
        if YouVersionAPI.hasPermission(BibleReaderViewModel.notesPermission), await YouVersionAPI.hasValidToken() {
            return
        }
        guard YouVersionPlatformConfiguration.isSignInEnabled else { throw YouVersionAPIError.missingAuthentication }
        let permissions = BibleReaderViewModel.signInPermissions
#if !os(tvOS)
        let result = try await YouVersionAPI.Users.signIn(permissions: permissions, contextProvider: contextProvider)
#else
        let result = try await YouVersionAPI.Users.signIn(permissions: permissions)
#endif
        guard result.permissionValues.contains(BibleReaderViewModel.notesPermission) else { throw YouVersionAPIError.notPermitted }
    }
}

private struct NoteHeader: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var draft: BibleReaderNoteDraft

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            HStack(alignment: .top) {
                Image(systemName: "bookmark")
                VStack(alignment: .leading, spacing: 2) {
                    Text(NoteStrings.save).font(.subheadline.bold())
                    Text(draft.referenceTitle).font(.caption)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }
            Button {
                draft.isPublic.toggle()
            } label: {
                Label(draft.isPublic ? NoteStrings.publicVisibility : NoteStrings.privateVisibility, systemImage: draft.isPublic ? "eye" : "eye.slash")
                    .font(.caption)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(viewModel.readerSurfaceTertiaryColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(draft.isSaving)
            .accessibilityIdentifier("notes.visibility")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
