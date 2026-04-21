import SwiftUI
import YouVersionPlatformCore

public struct BibleCardView: View {
    @State private var reference: BibleReference
    @State private var version: BibleVersion?
    @State private var isReferenceUnavailable = false
    private let textOptions: BibleTextOptions
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCopyrightSheet = false
    private let showVersionPicker: Bool
    private let onVersionChange: ((BibleVersion) -> Void)?

    public init(
        reference: BibleReference,
        fontFamily: String = "STIX Two Text",
        fontSize: CGFloat = 23,
        showVersionPicker: Bool = false,
        onVersionChange: ((BibleVersion) -> Void)? = nil
    ) {
        self.reference = reference
        self.version = nil
        self.textOptions = BibleTextOptions(
            fontFamily: fontFamily,
            fontSize: fontSize,
            textColor: Color.primary,
            verseNumColor: Color.secondary
        )
        self.showVersionPicker = showVersionPicker
        self.onVersionChange = onVersionChange
    }
    
    private func update(version: BibleVersion) {
        let updatedReference = referenceForVersionId(version.id)
        self.version = version
        reference = updatedReference
        isReferenceUnavailable = !updatedReference.existsIn(version: version)
        onVersionChange?(version)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                headerReference
                Spacer()
                if showVersionPicker {
                    BibleVersionPickingButton(initialVersionId: reference.versionId) { version in
                        update(version: version)
                    }
                }
            }
            if isReferenceUnavailable {
                unavailableReferenceView
            } else {
                BibleTextView(reference, textOptions: textOptions)
            }
            HStack(alignment: .top) {
                copyrightView
                    .padding(.trailing, 16)
                    .onTapGesture {
                        showingCopyrightSheet.toggle()
                    }
                Spacer()
                bibleAppLogo
            }
        }
        .padding()
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .task {
            if version == nil {
                if let loadedVersion = try? await BibleVersionRepository.shared.version(withId: reference.versionId) {
                    guard version == nil else {
                        return
                    }
                    version = loadedVersion
                    isReferenceUnavailable = !reference.existsIn(version: loadedVersion)
                }
            }
        }
        .sheet(isPresented: $showingCopyrightSheet) {
            ScrollView {
                Text(version?.localizedTitle ?? version?.title ?? "")
                    .font(YouVersionFonts.fontHeaderM)
                    .padding(.vertical)
                Text(version?.promotionalContent ?? version?.copyright ?? "")
                    .padding()
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
        }
    }
    
    private var foregroundColor: Color {
        colorScheme == .dark ? Color(hex: "#ffffff") : Color(hex: "#121212")
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#121212") : Color(hex: "#ffffff")
    }

    private var unavailableReferenceView: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
            Text(String.localized("bibleCard.unavailableReference"))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
    }
    
    private var headerReference: some View {
        if let version {
            let refText = version.displayTitle(for: reference)
            return Text(refText)
                .font(YouVersionFonts.fontEyebrowS.smallCaps())
                .tracking(1.5)
        }
        return Text("")
    }
    
    private var copyrightView: some View {
        let copyright = version?.copyright ?? version?.promotionalContent ?? ""
        return Text(copyright)
            .font(Font.system(size: 11))
            .fontWeight(.bold)
            .multilineTextAlignment(.leading)
            .minimumScaleFactor(0.7)
            .lineLimit(4)
    }
    
    private var bibleAppLogo: some View {
        Image("BibleAppLogotype@3x", bundle: .YouVersionUIBundle)
            .resizable()
            .frame(width: 106, height: 24)
    }

    private func referenceForVersionId(_ versionId: Int) -> BibleReference {
        if let verseStart = reference.verseStart {
            let verseEnd = reference.verseEnd ?? verseStart
            if verseStart == verseEnd {
                return BibleReference(
                    versionId: versionId,
                    bookUSFM: reference.bookUSFM,
                    chapter: reference.chapter,
                    verse: verseStart
                )
            }

            return BibleReference(
                versionId: versionId,
                bookUSFM: reference.bookUSFM,
                chapter: reference.chapter,
                verseStart: verseStart,
                verseEnd: verseEnd
            )
        }

        return BibleReference(
            versionId: versionId,
            bookUSFM: reference.bookUSFM,
            chapter: reference.chapter
        )
    }
    
}

#Preview {
    VStack(spacing: 16) {
        BibleCardView(
            reference: BibleReference(
                versionId: BibleVersion.preview.id, bookUSFM: "JHN", chapter: 1, verseStart: 1, verseEnd: 1
            )
        )
        .environment(\.colorScheme, .dark)
        
        BibleCardView(
            reference: BibleReference(
                versionId: BibleVersion.preview.id, bookUSFM: "JHN", chapter: 1, verseStart: 2, verseEnd: 2
            )
        )
        .environment(\.colorScheme, .light)
    }
    .frame(maxHeight: 400)
    .padding(.vertical)
    .background(.green)
}
