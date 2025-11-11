import SwiftUI
import YouVersionPlatformCore

public struct VotdView: View {
    @State private var backgroundUrl: String?
    @State private var reference: BibleReference?
    @State private var title: String?
    @Environment(\.colorScheme) private var colorScheme

    @State private var bibleVersionId: Int

    public init(bibleVersionId: Int = 111) {
        self.bibleVersionId = bibleVersionId
    }

    public var body: some View {
        Group {
            if let reference {
                textStack
                    .padding()
                    .foregroundStyle(backgroundUrl == nil ? Color.primary : Color.white)  // background images are dark
                    .background(
                        GeometryReader { geo in
                            if let backgroundUrl, let url = URL(string: backgroundUrl) {
                                votdBackground(url: url)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                        }
                    )
            } else {
                ProgressView()
            }
        }
        .task {
            guard reference == nil else {
                return
            }

            do {
                let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date())!
                let votdData = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: dayOfYear)
                if let version = try? await BibleVersionRepository.shared.version(withId: bibleVersionId),
                   let reference = version.reference(with: votdData.passageId) {
                    self.reference = reference
                    self.title = version.displayTitle(for: reference, includesVersionAbbreviation: true)
                } else {
                    print("VotdView: could not load version, or reference is invalid for this version")
                }
            } catch {
                print("VotdView: error loading votd: \(error)")
            }
        }
    }
    
    private func votdBackground(url: URL) -> some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                EmptyView()
            }
        }
    }
    
    private var textStack: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Image("votd", bundle: .YouVersionBundle)
                    .renderingMode(.template)  // to be right in dark mode
                    .resizable()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    let light = colorScheme == .light
                    Text(String.localized("tab.votd"))
                        .font(Font.system(size: 12).bold().smallCaps())
                        .foregroundStyle(light ? Color(hex: "#636161") : Color(hex: "#bfbdbd"))
                    if let title {
                        Text(title)
                            .font(Font.system(size: 16).bold())
                            .lineLimit(1)
                            .padding(.bottom, 16)
                    } else {
                        ProgressView()
                    }
                }
            }
            if let reference {
                let textOptions = BibleTextOptions(fontSize: 24, renderVerseNumbers: false)
                BibleTextView(reference, textOptions: textOptions)
                    .minimumScaleFactor(0.5)
                    .textSelection(.enabled)
                    .padding(.bottom, 16)
            } else {
                ProgressView()
            }
        }
    }
}

#Preview {
    VotdView(bibleVersionId: 206)
}
