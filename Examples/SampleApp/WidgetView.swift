import SwiftUI
import YouVersionPlatform

struct WidgetView: View {
    var body: some View {
        ScrollView {
            BibleWidgetView(
                reference: BibleReference(
                    versionId: 111, bookUSFM: "GEN", chapter: 2, verseStart: 1, verseEnd: 3
                ),
                fontSize: 18
            )
            BibleWidgetView(
                reference: BibleReference(
                    versionId: 111, bookUSFM: "GEN", chapter: 2, verseStart: 1, verseEnd: 4
                ),
                fontSize: 18
            )
            BibleWidgetView(
                reference: BibleReference(
                    versionId: 111, bookUSFM: "GEN", chapter: 2, verseStart: 3, verseEnd: 4
                ),
                fontSize: 18
            )
            BibleWidgetView(
                reference: BibleReference(
                    versionId: 111, bookUSFM: "MAT", chapter: 5, verseStart: 1, verseEnd: 1
                ),
                fontSize: 18
            )
            BibleWidgetView(
                reference: BibleReference(
                    versionId: 111, bookUSFM: "MAT", chapter: 5, verseStart: 1, verseEnd: 2
                ),
                fontSize: 18
            )
        }
    }
}

#Preview {
    VStack {
        WidgetView()
        Spacer()
    }
    .padding(.vertical, 8)
    .background(.blue)
}
