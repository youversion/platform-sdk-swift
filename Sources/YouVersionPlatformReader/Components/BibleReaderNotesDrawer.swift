import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderNotesDrawer: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Bindable var draft: BibleReaderNoteDraft
    @FocusState private var isEditing: Bool
    @State private var noteToDelete: YouVersionNote?
    @State private var showingDeleteConfirmation = false
    @State private var noteToCopy: YouVersionNote?
    @State private var showingReplaceConfirmation = false
    @State private var contentHeight: CGFloat = 240
#if !os(tvOS)
    @State private var contextProvider = ReaderAuthenticationContextProvider()
#endif

    var body: some View {
        List {
            VStack(spacing: 8) {
                HStack {
                    Button {
                        viewModel.requestDismissNote()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.title3.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(String.localized("generic.back"))
                    .accessibilityIdentifier("notes.back")
                    .disabled(draft.isBusy)
                    Spacer()
                }
                NoteHeader(draft: draft)
                TextField(NoteStrings.placeholder, text: $draft.content, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.body)
                    .padding(12)
                    .background(viewModel.readerSurfaceTertiaryColor, in: RoundedRectangle(cornerRadius: 8))
                    .focused($isEditing)
                    .accessibilityIdentifier("notes.content")
                    .disabled(draft.isBusy)
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
                .disabled(draft.isBusy)
                cancelAndSaveButtons

            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            .buttonStyle(.borderless)
            .labelStyle(.titleAndIcon)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(viewModel.readerCanvasPrimaryColor)
            if !draft.savedNotes.isEmpty {
                VStack(spacing: 8) {
                    Divider().padding(.vertical, 16)
                    Text(NoteStrings.previouslySaved)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 8, trailing: 24))
                .listRowSeparator(.hidden)
                .listRowBackground(viewModel.readerCanvasPrimaryColor)
                ForEach(draft.savedNotes) { note in
                    SavedNoteCard(note: note)
                        .contentShape(Rectangle())
                        .modifier(BibleReaderNoteTapModifier { selectSavedNote(note) })
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { selectSavedNote(note) }
                        .allowsHitTesting(!draft.isBusy)
                        .labelStyle(.titleAndIcon)
                        .disabled(draft.isBusy)
                        .modifier(SavedNoteActions(isEnabled: !draft.isBusy) {
                            noteToDelete = note
                            showingDeleteConfirmation = true
                        })
                        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))
                        .listRowSeparator(.hidden)
                        .listRowBackground(viewModel.readerCanvasPrimaryColor)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(viewModel.readerCanvasPrimaryColor)
        .contentMargins(.vertical, 0, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .presentationDetents(draft.savedNotes.isEmpty ? [.height(contentHeight), .large] : [.large])
        .modifier(BibleReaderNoteDismissalModifier(draft: draft))
        .confirmationDialog(NoteStrings.replaceTitle, isPresented: $showingReplaceConfirmation, titleVisibility: .visible) {
            Button(NoteStrings.replace, role: .destructive) {
                if let noteToCopy { copyText(from: noteToCopy) }
                noteToCopy = nil
            }
            Button(String.localized("generic.cancel"), role: .cancel) { noteToCopy = nil }
        } message: {
            Text(NoteStrings.replaceMessage)
        }
        .alert(NoteStrings.deleteTitle, isPresented: $showingDeleteConfirmation, presenting: noteToDelete) { note in
            Button(NoteStrings.delete, role: .destructive) {
                Task { _ = await draft.delete(note, authorize: authorize) }
                noteToDelete = nil
            }
            Button(String.localized("generic.cancel"), role: .cancel) { noteToDelete = nil }
        } message: { _ in
            Text(NoteStrings.deleteMessage)
        }
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
                .disabled(draft.isBusy)
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

    private func selectSavedNote(_ note: YouVersionNote) {
        guard !draft.isBusy else {
            return
        }
        if draft.hasTextChanges && draft.content != note.content {
            noteToCopy = note
            showingReplaceConfirmation = true
        } else {
            copyText(from: note)
        }
    }

    private func copyText(from note: YouVersionNote) {
        draft.copyText(from: note)
        isEditing = true
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
            .disabled(draft.isBusy)
            .accessibilityIdentifier("notes.visibility")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SavedNoteCard: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let note: YouVersionNote

    private var referenceTitle: String {
        guard let references = note.passage?.references else {
            return note.passage?.passageID ?? ""
        }
        return references.map {
            viewModel.version?.displayTitle(for: $0, includesVersionAbbreviation: false) ?? $0.passageId
        }.joined(separator: String.localized("shareableVerse.referencesSeparator"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) {
                    title
                    Spacer(minLength: 8)
                    visibility
                }
                VStack(alignment: .leading, spacing: 8) {
                    title
                    visibility
                }
            }
            Text(note.content)
                .font(.body)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(viewModel.readerSurfaceTertiaryColor, in: RoundedRectangle(cornerRadius: 8))
            HStack {
                if let color = note.color {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 8)
                if let createdTime = note.createdTime {
                    BibleReaderNoteAge(createdTime: createdTime)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(viewModel.readerCanvasPrimaryColor, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(viewModel.readerTextPrimaryColor.opacity(0.1))
        }
    }

    private var title: some View {
        Text(NoteStrings.addedNote + " " + referenceTitle)
            .font(.subheadline)
            .multilineTextAlignment(.leading)
    }

    private var visibility: some View {
        Label(
            note.status == .public ? NoteStrings.publicVisibility : NoteStrings.privateVisibility,
            systemImage: note.status == .public ? "eye" : "eye.slash"
        )
            .font(.caption)
            .fixedSize()
    }
}

private struct SavedNoteActions: ViewModifier {
    let isEnabled: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
#if !os(tvOS)
        content.swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteButton
        }
#else
        content
#endif
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Label(NoteStrings.delete, systemImage: "trash")
        }
        .tint(.red)
        .disabled(!isEnabled)
    }
}
