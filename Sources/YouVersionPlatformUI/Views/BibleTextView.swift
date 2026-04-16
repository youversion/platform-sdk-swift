import SwiftUI
import YouVersionPlatformCore

public struct BibleTextView: View {

    public typealias VerseTapAction = (BibleReference, String, [BibleFootnote], String?) -> Void

    private let reference: BibleReference
    private let textOptions: BibleTextOptions
    private let onVerseTap: VerseTapAction?
    private let placeholder: (BibleTextLoadingPhase) -> AnyView
    private let providedBlocks: [BibleTextBlock]?
    @State private var isVersionRightToLeft = false
    @State private var blocks: [BibleTextBlock]
    @State private var loadingPhase: BibleTextLoadingPhase?
    // swiftlint:disable:next private_swiftui_state
    @State var ourHighlights: [BibleHighlight] = []
    @Binding var selectedVerses: Set<BibleReference>
    @Environment(\.layoutDirection) private var systemLayoutDirection

    public init(
        _ reference: BibleReference,
        textOptions: BibleTextOptions? = nil,
        onVerseTap: VerseTapAction? = nil
    ) {
        self.reference = reference
        self.textOptions = textOptions ?? BibleTextOptions()
        self.onVerseTap = onVerseTap
        self._selectedVerses = .constant([])
        self.placeholder = Self.standardPlaceholder
        self.blocks = []
        self.providedBlocks = nil
    }

    public init(
        _ reference: BibleReference,
        textOptions: BibleTextOptions? = nil,
        selectedVerses: Binding<Set<BibleReference>>,
        onVerseTap: VerseTapAction? = nil,
        placeholder: ((BibleTextLoadingPhase) -> AnyView)? = nil
    ) {
        self.reference = reference
        self.textOptions = textOptions ?? BibleTextOptions()
        self._selectedVerses = selectedVerses
        self.onVerseTap = onVerseTap
        self.placeholder = placeholder ?? Self.standardPlaceholder
        self.blocks = []
        self.providedBlocks = nil
    }

    // private init for use by Self.viewWithPrefetchedData()
    private init(
        _ reference: BibleReference,
        blocks: [BibleTextBlock] = [],
        textOptions: BibleTextOptions? = nil,
        onVerseTap: VerseTapAction? = nil
    ) {
        self.reference = reference
        self.textOptions = textOptions ?? BibleTextOptions()
        self.onVerseTap = onVerseTap
        self._selectedVerses = .constant([])
        self.placeholder = Self.standardPlaceholder
        self.blocks = blocks
        self.providedBlocks = blocks
    }

    public var body: some View {
        VStack(alignment: mainVStackAlignment) {
            if let phase = loadingPhase {
                placeholder(phase)
            } else {
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    view(for: block, textOptions: textOptions, ignoreMarginTop: index == 0)
                }
            }
        }
        .environment(\.openURL, OpenURLAction(handler: { url in
            if let reference = parseReference(url: url) {
                let footnodeId = url.fragment()
                let footnotes = footnotesFor(reference: reference)
                onVerseTap?(reference, url.scheme ?? BibleVersionRendering.LinkSchemes.reference.rawValue, footnotes, footnodeId)
            }
            return .handled
        }))
        .task(id: "\(reference)\(textOptions.fontSize)\(textOptions.fontFamily)\(textOptions.textColor ?? .clear)") {
            await loadBlocks()
        }
        .coordinateSpace(name: "BibleTextView")
        .task(id: reference) {
            BibleHighlightsViewModel.shared.ensureHighlightsForChapterLoaded(reference)
        }
        .onChange(of: reference) {
            ourHighlights = BibleHighlightsCache.shared.highlights(overlapping: reference)
        }
        .onChange(of: BibleHighlightsCache.shared.cachedHighlights) { _, _ in
            ourHighlights = BibleHighlightsCache.shared.highlights(overlapping: reference)
        }
    }

    private func footnotesFor(reference: BibleReference) -> [BibleFootnote] {
        var footnotes: [BibleFootnote] = []
        for block in blocks {
            for footnote in block.footnotes where footnote.reference == reference {
                footnotes.append(footnote)
            }
        }
        return footnotes
    }

    private func parseReference(url: URL) -> BibleReference? {
        guard url.scheme == BibleVersionRendering.LinkSchemes.reference.rawValue || url.scheme == BibleVersionRendering.LinkSchemes.footnote.rawValue,
              let host = url.host,
              let versionId = Int(host) else {
            return nil
        }
        guard url.pathComponents.count > 1,
              let parts = url.pathComponents.last?.split(separator: "."),
              parts.count == 3 else {
            return nil
        }
        let book = String(parts[0])
        if let chapter = Int(parts[1]),
           let verse = Int(parts[2]) {
            return BibleReference(versionId: versionId, bookUSFM: book, chapter: chapter, verse: verse)
        }
        return nil
    }

    // Our main VStack's alignment needs to be flipped when the system's text direction
    // isn't the same as our Bible version's text direction, otherwise multiline text
    // views will be placed on the wrong side of the VStack.
    private var mainVStackAlignment: HorizontalAlignment {
        if systemLayoutDirection == .leftToRight {
            return isVersionRightToLeft ? .trailing : .leading
        }
        return isVersionRightToLeft ? .leading : .trailing
    }

    private func updateVersionTextDirection() async {
        if let version = try? await BibleVersionRepository.shared.version(withId: reference.versionId) {
            isVersionRightToLeft = version.isRightToLeft
        } else {
            isVersionRightToLeft = false  // probably cannot happen: we will have the version object available to us
        }
    }

    private func loadBlocks() async {
        loadingPhase = .loading
        do {
            if let providedBlocks {
                self.blocks = providedBlocks
                await updateVersionTextDirection()
                loadingPhase = nil  // meaning, we've succeeded
            } else if let blocks = try await BibleVersionRendering.textBlocks(
                reference: reference,
                renderHeadlines: textOptions.renderHeadlines,
                renderVerseNumbers: textOptions.renderVerseNumbers,
                footnotesMode: textOptions.footnoteMode,
                footnoteMarker: textOptions.footnoteMarker,
                textColor: textOptions.textColor ?? Color.primary,
                verseNumColor: textOptions.verseNumColor ?? Color.secondary,
                wocColor: textOptions.wocColor,
                fonts: BibleTextFonts(familyName: textOptions.fontFamily, baseSize: textOptions.fontSize)
            ) {
                self.blocks = blocks
                await updateVersionTextDirection()
                loadingPhase = nil  // meaning, we've succeeded
            } else {
                loadingPhase = .failed
            }
        } catch YouVersionAPIError.notPermitted {
            loadingPhase = .notPermitted
        } catch is CancellationError {
            loadingPhase = .inactive
        } catch let err {
            YouVersionPlatformLogger.error("loadBlocks unexpected error: \(err)", category: "BibleText")
            loadingPhase = .failed
        }
    }

    public static func viewWithPrefetchedData(
        reference: BibleReference,
        fontFamily: String = "Times New Roman",
        fontSize: CGFloat = 16
    ) async -> (some View)? {
        do {
            guard let blocks = try? await BibleVersionRendering.textBlocks(
                reference: reference,
                fonts: BibleTextFonts(familyName: fontFamily, baseSize: fontSize)
            ) else {
                return nil as BibleTextView?
            }
            return BibleTextView(reference, blocks: blocks)
        }
    }

    public static func viewFromHtml(
        html: String,
        reference: BibleReference,
        textOptions: BibleTextOptions,
        onVerseTap: VerseTapAction? = nil
    ) -> (some View)? {
        let node = try? BibleTextNode(html: html)
        return VStack {
            if node?.children.count ?? 0 == 0 {
                Text("")
            } else {
                let blocks = BibleVersionRendering.generateTextBlocks(
                    from: node!,
                    reference: reference,
                    renderHeadlines: false,
                    renderVerseNumbers: false,
                    footnotesMode: textOptions.footnoteMode,
                    footnoteMarker: textOptions.footnoteMarker,
                    textColor: textOptions.textColor ?? Color.primary,
                    verseNumColor: textOptions.verseNumColor ?? Color.secondary,
                    wocColor: textOptions.wocColor,
                    fonts: BibleTextFonts(familyName: textOptions.fontFamily, baseSize: textOptions.fontSize)
                )
                if !blocks.isEmpty {
                    BibleTextView(reference, blocks: blocks, textOptions: textOptions, onVerseTap: onVerseTap)
                        .id("\(html)(\(textOptions.fontFamily)_\(textOptions.fontSize))") // without this, it won't adjust e.g. size immediately
                } else {
                    Text("")
                }
            }
        }
    }

    // TODO: debug why this is necessary. Text objects should get it right automatically.
    func flipAlignmentIfNecessary(_ alignment: TextAlignment) -> TextAlignment {
        if isVersionRightToLeft {
            if alignment == .center {
                return alignment
            }
            return alignment == .trailing ? .leading : .trailing
        } else {
            return alignment
        }
    }

    private static func standardPlaceholder(phase: BibleTextLoadingPhase) -> AnyView {
        let height = 80.0
        let v = Group {
            switch phase {
            case .inactive:
                EmptyView()
            case .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            case .notPermitted:
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .padding()
                    Text(String.localized("bibleText.unavailableVersion"))
                }
            case .failed:
                HStack {
                    Image(systemName: "wifi.slash")
                        .padding()
                    Text(String.localized("bibleText.connectionIssue"))
                }
            }
        }
        return AnyView(v.frame(height: height))
    }

}

public struct BibleTextOptions {
    public let fontFamily: String
    public let fontSize: CGFloat
    public let lineSpacing: CGFloat?
    public let paragraphSpacing: CGFloat?
    public let textColor: Color?
    public let verseNumColor: Color?
    public let wocColor: Color
    public let renderHeadlines: Bool
    public let renderVerseNumbers: Bool
    public let footnoteMode: BibleTextFootnoteMode
    public let footnoteMarker: BibleAttributedString?

    public init(fontFamily: String = "Times New Roman",
                fontSize: CGFloat = 16,
                lineSpacing: CGFloat? = nil,
                paragraphSpacing: CGFloat? = nil,
                textColor: Color? = nil,
                verseNumColor: Color? = nil,
                wocColor: Color = Color(red: 1, green: 0x3d / 255.0, blue: 0x4d / 255.0),   // YouVersion red. F04C59 in dark mode.
                renderHeadlines: Bool = true,
                renderVerseNumbers: Bool = true,
                footnoteMode: BibleTextFootnoteMode = .none,
                footnoteMarker: BibleAttributedString? = nil) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing ?? fontSize / 2
        self.paragraphSpacing = paragraphSpacing ?? fontSize / 2
        self.textColor = textColor
        self.verseNumColor = verseNumColor
        self.wocColor = wocColor
        self.renderHeadlines = renderHeadlines
        self.renderVerseNumbers = renderVerseNumbers
        self.footnoteMode = footnoteMode
        self.footnoteMarker = footnoteMarker
    }
}

public enum BibleTextLoadingPhase {
    case inactive
    case loading
    case failed
    case notPermitted
}
