import SwiftUI
import YouVersionPlatform

struct WidgetView: View {
    var body: some View {
        BibleWidgetView(
            reference: BibleReference(
                versionId: 111, bookUSFM: "2CO", chapter: 1, verseStart: 3, verseEnd: 4
            ),
            fontSize: 18
        )
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
