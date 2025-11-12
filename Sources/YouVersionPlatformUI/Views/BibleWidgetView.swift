import SwiftUI
import YouVersionPlatformCore

public struct BibleWidgetView: View {
    public let reference: BibleReference
    @State private var version: BibleVersion?
    private let textOptions: BibleTextOptions
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCopyrightSheet = false

    public init(reference: BibleReference, fontSize: CGFloat = 23) {
        self.reference = reference
        self.version = nil
        self.textOptions = BibleTextOptions(
            fontFamily: "Georgia",
            fontSize: fontSize,
            textColor: Color.primary
        )
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                headerReference
                Spacer()
            }
            BibleTextView(reference, textOptions: textOptions)
            HStack(alignment: .top) {
                copyrightView
                    .padding(.trailing, 16)
                    .onTapGesture {
                        showingCopyrightSheet.toggle()
                    }
                Spacer()
                poweredByYouVersionView
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
                Text(version?.localizedTitle ?? "")
                    .font(Font.system(size: 20, weight: .bold))  // YouVersion HeaderM
                    .padding(.vertical)
                Text(version?.copyrightLong ?? version?.copyrightShort ?? "")
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
                .font(fontEyebrowS.smallCaps())
                .tracking(1.5)
        }
        return Text("")
    }

    private var fontEyebrowS: Font {
        Font.system(size: 11, weight: .bold)
    }

    private var copyrightView: some View {
        let copyright = version?.copyrightShort ?? version?.copyrightLong ?? ""
        return Text(copyright)
            .font(Font.system(size: 11))
            .fontWeight(.bold)
            .multilineTextAlignment(.leading)
            .minimumScaleFactor(0.7)
            .lineLimit(4)
    }

    private var poweredByYouVersionView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .trailing) {
                Text(String.localized("widget.poweredBy"))
                    .italic()
                Text("YouVersion")
                    .fontWeight(.bold)
            }
            .font(Font.system(size: 11))
            bibleAppLogo
                .frame(width: 28, height: 28)
        }
    }

    private var bibleAppLogo: some View {
        Image("BibleAppLogo@4x", bundle: .YouVersionUIBundle)
            .resizable()
    }

}

#Preview {
    VStack(spacing: 16) {
        BibleWidgetView(
            reference: BibleReference(
                versionId: BibleVersion.preview.id, bookUSFM: "JHN", chapter: 1, verseStart: 1, verseEnd: 1
            )
        )
        .environment(\.colorScheme, .dark)

        BibleWidgetView(
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
