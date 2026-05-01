import SwiftUI
import YouVersionPlatformCore

public struct BibleTextView: View {

    public typealias VerseTapAction = (BibleReference, String, [BibleFootnote], String?) -> Void

    private let reference: BibleReference
    private let textOptions: BibleTextOptions
    private let onVerseTap: VerseTapAction?
    private let placeholder: ((BibleTextLoadingPhase) -> AnyView)?
    private let providedBlocks: [BibleTextBlock]?
    private let sourceHTML: String?
    @State private var isVersionRightToLeft = false
    @State private var blocks: [BibleTextBlock]
    @State private var loadingPhase: BibleTextLoadingPhase?
    @Binding var selectedVerses: Set<BibleReference>

    var ourHighlights: [BibleHighlight] {
        BibleHighlightsCache.shared.highlights(overlapping: reference)
    }

    public init(
        _ reference: BibleReference,
        textOptions: BibleTextOptions? = nil,
        onVerseTap: VerseTapAction? = nil
    ) {
        self.reference = reference
        self.textOptions = textOptions ?? BibleTextOptions()
        self.onVerseTap = onVerseTap
        self._selectedVerses = .constant([])
        self.placeholder = nil
        self.blocks = []
        self.providedBlocks = nil
        self.sourceHTML = nil
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
        self.placeholder = placeholder
        self.blocks = []
        self.providedBlocks = nil
        self.sourceHTML = nil
    }

    /// Renders Bible text from a pre-parsed HTML string.
    ///
    /// The HTML is parsed synchronously at init time. The view re-parses and
    /// re-renders when `html`, `reference`, or any text-style input changes.
    public init(
        html: String,
        reference: BibleReference,
        textOptions: BibleTextOptions = BibleTextOptions(),
        onVerseTap: VerseTapAction? = nil
    ) {
        let blocks = Self.blocks(parsedFrom: html, reference: reference, textOptions: textOptions)
        self.init(reference, blocks: blocks, textOptions: textOptions, onVerseTap: onVerseTap, sourceHTML: html)
    }

    private init(
        _ reference: BibleReference,
        blocks: [BibleTextBlock] = [],
        textOptions: BibleTextOptions? = nil,
        onVerseTap: VerseTapAction? = nil,
        sourceHTML: String? = nil
    ) {
        self.reference = reference
        self.textOptions = textOptions ?? BibleTextOptions()
        self.onVerseTap = onVerseTap
        self._selectedVerses = .constant([])
        self.placeholder = nil
        self.blocks = blocks
        self.providedBlocks = blocks
        self.sourceHTML = sourceHTML
    }

    private static func blocks(
        parsedFrom html: String,
        reference: BibleReference,
        textOptions: BibleTextOptions
    ) -> [BibleTextBlock] {
        guard let node = try? BibleTextNode(html: html), !node.children.isEmpty else {
            return []
        }
        return BibleVersionRendering.textBlocks(
            parsedFrom: node,
            reference: reference,
            renderHeadlines: false,
            renderVerseNumbers: false,
            footnotesMode: textOptions.footnoteMode,
            footnoteMarker: textOptions.footnoteMarker,
            textColor: textOptions.textColor ?? Color.primary,
            verseNumColor: textOptions.verseNumberColor ?? Color.secondary,
            wocColor: textOptions.wordsOfChristColor,
            fonts: BibleTextFonts(familyName: textOptions.fontFamily, baseSize: textOptions.fontSize)
        )
    }

    public var body: some View {
        VStack(alignment: .leading) {
            if let phase = loadingPhase {
                if let placeholder {
                    placeholder(phase)
                } else {
                    standardPlaceholder(phase: phase)
                }
            } else {
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    view(for: block, textOptions: textOptions, ignoreMarginTop: index == 0)
                }
            }
        }
        .environment(\.layoutDirection, isVersionRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.openURL, OpenURLAction(handler: { url in
            if let reference = parseReference(url: url) {
                let footnodeId = url.fragment()
                let footnotes = footnotesFor(reference: reference)
                onVerseTap?(reference, url.scheme ?? BibleVersionRendering.LinkSchemes.reference.rawValue, footnotes, footnodeId)
            }
            return .handled
        }))
        .task(id: LoadKey(
            reference: reference,
            fontSize: textOptions.fontSize,
            fontFamily: textOptions.fontFamily,
            textColor: textOptions.textColor,
            sourceHTML: sourceHTML
        )) {
            await loadBlocks()
        }
        .coordinateSpace(.named("BibleTextView"))
        .task(id: reference) {
            BibleHighlightsViewModel.shared.ensureHighlightsForChapterLoaded(reference)
        }
    }

    private func footnotesFor(reference: BibleReference) -> [BibleFootnote] {
        blocks.flatMap(\.footnotes).filter { $0.reference == reference }
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

    private func updateVersionTextDirection() async {
        if let version = try? await BibleVersionRepository.shared.version(withId: reference.versionId) {
            isVersionRightToLeft = version.isRightToLeft
        } else {
            isVersionRightToLeft = false  // probably cannot happen: we will have the version object available to us
        }
    }

    private func loadBlocks() async {
        // Only enter the loading phase for the network path. The html: init
        // pre-parses blocks synchronously at init time, so rendering them
        // immediately on first frame avoids a placeholder flash while
        // updateVersionTextDirection() does its async lookup.
        if providedBlocks == nil {
            loadingPhase = .loading
        }
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
                verseNumColor: textOptions.verseNumberColor ?? Color.secondary,
                wocColor: textOptions.wordsOfChristColor,
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

    @available(*, deprecated, renamed: "init(html:reference:textOptions:onVerseTap:)")
    public static func viewFromHtml(
        html: String,
        reference: BibleReference,
        textOptions: BibleTextOptions,
        onVerseTap: VerseTapAction? = nil
    ) -> (some View)? {
        BibleTextView(html: html, reference: reference, textOptions: textOptions, onVerseTap: onVerseTap)
    }

    @available(*, deprecated, message: "Prefetch blocks with BibleVersionRendering.textBlocks(reference:fonts:) and construct BibleTextView directly. This API will be removed in a future major version.")
    public static func viewWithPrefetchedData(
        reference: BibleReference,
        fontFamily: String = "Times New Roman",
        fontSize: CGFloat = 16
    ) async -> (some View)? {
        guard let blocks = try? await BibleVersionRendering.textBlocks(
            reference: reference,
            fonts: BibleTextFonts(familyName: fontFamily, baseSize: fontSize)
        ) else {
            return nil as BibleTextView?
        }
        return BibleTextView(reference, blocks: blocks)
    }

    @ViewBuilder
    private func standardPlaceholder(phase: BibleTextLoadingPhase) -> some View {
        Group {
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
        .frame(height: 80)
    }

    private struct LoadKey: Hashable {
        let reference: BibleReference
        let fontSize: CGFloat
        let fontFamily: String
        let textColor: Color?
        let sourceHTML: String?
    }

}

public struct BibleTextOptions {
    public let fontFamily: String
    public let fontSize: CGFloat
    public let lineSpacing: CGFloat?
    public let paragraphSpacing: CGFloat?
    public let textColor: Color?
    public let verseNumberColor: Color?
    public let wordsOfChristColor: Color
    public let renderHeadlines: Bool
    public let renderVerseNumbers: Bool
    public let footnoteMode: BibleTextFootnoteMode
    public let footnoteMarker: BibleAttributedString?
    public let verseSelectionStyle: VerseSelectionStyle

    public init(fontFamily: String = "Times New Roman",
                fontSize: CGFloat = 16,
                lineSpacing: CGFloat? = nil,
                paragraphSpacing: CGFloat? = nil,
                textColor: Color? = nil,
                verseNumberColor: Color? = nil,
                wordsOfChristColor: Color = Color(red: 1, green: 0x3d / 255.0, blue: 0x4d / 255.0),   // YouVersion red. F04C59 in dark mode.
                renderHeadlines: Bool = true,
                renderVerseNumbers: Bool = true,
                footnoteMode: BibleTextFootnoteMode = .none,
                footnoteMarker: BibleAttributedString? = nil,
                verseSelectionStyle: VerseSelectionStyle = .solid) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing ?? fontSize / 2
        self.paragraphSpacing = paragraphSpacing ?? fontSize / 2
        self.textColor = textColor
        self.verseNumberColor = verseNumberColor
        self.wordsOfChristColor = wordsOfChristColor
        self.renderHeadlines = renderHeadlines
        self.renderVerseNumbers = renderVerseNumbers
        self.footnoteMode = footnoteMode
        self.footnoteMarker = footnoteMarker
        self.verseSelectionStyle = verseSelectionStyle
    }

    @available(*, deprecated, renamed: "verseNumberColor")
    public var verseNumColor: Color? { verseNumberColor }

    @available(*, deprecated, renamed: "wordsOfChristColor")
    public var wocColor: Color { wordsOfChristColor }

    @available(*, deprecated, message: "Use init(... verseNumberColor: ..., wordsOfChristColor: ...) instead.")
    @_disfavoredOverload
    public init(fontFamily: String = "Times New Roman",
                fontSize: CGFloat = 16,
                lineSpacing: CGFloat? = nil,
                paragraphSpacing: CGFloat? = nil,
                textColor: Color? = nil,
                verseNumColor: Color? = nil,
                wocColor: Color = Color(red: 1, green: 0x3d / 255.0, blue: 0x4d / 255.0),
                renderHeadlines: Bool = true,
                renderVerseNumbers: Bool = true,
                footnoteMode: BibleTextFootnoteMode = .none,
                footnoteMarker: BibleAttributedString? = nil,
                verseSelectionStyle: VerseSelectionStyle = .solid) {
        self.init(
            fontFamily: fontFamily,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            paragraphSpacing: paragraphSpacing,
            textColor: textColor,
            verseNumberColor: verseNumColor,
            wordsOfChristColor: wocColor,
            renderHeadlines: renderHeadlines,
            renderVerseNumbers: renderVerseNumbers,
            footnoteMode: footnoteMode,
            footnoteMarker: footnoteMarker,
            verseSelectionStyle: verseSelectionStyle
        )
    }
}

public enum BibleTextLoadingPhase {
    case inactive
    case loading
    case failed
    case notPermitted
}
