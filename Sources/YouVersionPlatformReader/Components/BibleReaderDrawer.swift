import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleReaderDrawer: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    var actions: [BibleReaderVerseAction] = [.highlight, .save, .copy, .share]

    var body: some View {
        VStack {
            Divider()
            Rectangle()
                .frame(width: 30, height: 2)
                .padding(.top, 4)
                .padding(.bottom, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(actions) { action in
                        switch action.kind {
                        case .highlight:
                            highlightColorButtons
                        case .save:
                            drawerButton(imageName: "bookmark", text: NoteStrings.save) { viewModel.startNote() }
                        case .copy:
#if !os(tvOS)
                            drawerButton(imageName: "square.on.square", text: .localized("verseActions.copy")) {
                                viewModel.handleVerseActionCopy()
                            }
#endif
                        case .share:
#if !os(tvOS)
                            if let (url, title) = viewModel.shareableURLAndTitleForSelection {
                                ShareLink(item: url, message: Text(title)) {
                                    VerseActionLabel(image: Image(systemName: "square.and.arrow.up"), title: Text(String.localized("verseActions.share")))
                                }
                            }
#endif
                        case .custom:
                            if let title = action.title, let image = action.image {
                                Button {
                                    let references = BibleReference.referencesByMerging(references: Array(viewModel.selectedVerses).sorted())
                                    viewModel.removeVerseSelection()
                                    action.action?(references)
                                } label: {
                                    VerseActionLabel(image: image, title: Text(title))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)
        }
        .foregroundStyle(viewModel.readerTextMutedColor)
        .background(viewModel.readerCanvasPrimaryColor)
    }

    private var highlightColorButtons: some View {
        let palette = BibleReaderHighlightColors.palette
        let selectedHexes = viewModel.highlightHexesOnSelectedVerses
            .filter { Color.rgbValue(fromHex: $0) != nil }
            .sorted { (palette.firstIndex(of: $0) ?? .max, $0) < (palette.firstIndex(of: $1) ?? .max, $1) }
        let availableHexes = palette.filter { !viewModel.isColorPresentOnAllSelectedVerses(Color(hex: $0)) }
        return BibleReaderHighlightColors(
            selectedHexes: selectedHexes, availableHexes: availableHexes,
            onRemove: { viewModel.removeVerseColor(hex: $0) },
            onAdd: { viewModel.addVerseColor(Color(hex: $0)) }
        )
    }

    private func drawerButton(imageName: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VerseActionLabel(image: Image(systemName: imageName), title: Text(text))
        }
    }
}

private struct VerseActionLabel: View {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let image: Image
    let title: Text

    var body: some View {
        VStack(spacing: 0) {
            image
                .padding(.bottom, 6)
            title
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 44, minHeight: 55)
        .background(viewModel.readerSurfaceTertiaryColor, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(viewModel.readerTextPrimaryColor)
        .font(YouVersionFonts.labelMedium)
        .contentShape(Rectangle())
    }
}

#Preview {
    BibleReaderDrawer()
        .environment(BibleReaderViewModel.preview)
}
