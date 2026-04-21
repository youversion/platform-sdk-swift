import SwiftUI
import YouVersionPlatformCore

public struct BibleCardView: View {
    @State private var reference: BibleReference
    @State private var version: BibleVersion?
    private let textOptions: BibleTextOptions
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCopyrightSheet = false
    @State private var showVersionPicker: Bool
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
    
    func update(version: BibleVersion) {
        self.version = version
        // TODO Check if the book, chapter, and/or range is present in this version. Show error if not.
        reference = BibleReference(
            versionId: version.id,
            bookUSFM: reference.bookUSFM,
            chapter: reference.chapter,
            verseStart: reference.verseStart ?? 1,
            verseEnd: reference.verseEnd ?? 999  // TODO better
        )
        onVersionChange?(version)
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                headerReference
                Spacer()
                if showVersionPicker {
                    BibleVersionPickingButton(initialVersionId: reference.versionId) { version in
                        update(version: version)
                        // TODO
                        //                    } label: { //versionId in
                        //                        Text(version?.localizedAbbreviation ?? "")
                        //                        .font(.system(size: 14))
                        //                        .fontWeight(.bold)
                        //                        .padding(.vertical, 8)
                        //                        .padding(.horizontal, 16)
                        //                        .frame(minWidth: 50)
                        //                        .background(
                        //                            Capsule()
                        //                                .fill(colorScheme == .dark ? Color(hex: "#353333") : Color(hex: "#edebeb"))  // readerButtonPrimaryColor
                        //                        )
                        
                    }
                }
            }
            BibleTextView(reference, textOptions: textOptions)
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
                version = try? await BibleVersionRepository.shared.version(withId: reference.versionId)
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
