import SwiftUI
import YouVersionPlatform

struct CardView: View {
    var body: some View {
        BibleCardView(
            reference: BibleReference(
                versionId: 3034, bookUSFM: "2CO", chapter: 1, verseStart: 3, verseEnd: 4
            ),
            fontSize: 18
        )
    }
}

#Preview {
    VStack {
        CardView()
        Spacer()
    }
    .padding(.vertical, 8)
    .background(.blue)
}
