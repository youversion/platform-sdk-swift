import SwiftUI
import YouVersionPlatformCore

struct BibleReaderHalfPillPickersView: View {
    let bookAndChapter: String
    let versionAbbreviation: String
    let handleChapterTap: () -> Void
    let handleVersionTap: () -> Void
    let foregroundColor: Color
    let buttonColor: Color
    let backgroundColor: Color
    let compactMode: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { handleChapterTap() }) {
                Text(bookAndChapter)
                    .font(.system(size: compactMode ? 10 : 14, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(2)
                    .frame(minWidth: compactMode ? 53 : 60)
                    .frame(height: compactMode ? 29 : 40)
                    .padding(.leading, compactMode ? 14 : 16)
                    .padding(.trailing, compactMode ? 12 : 14)
            }
            .buttonStyle(PlainButtonStyle())
            .clipShape(HalfPillShape(side: .left))

            Rectangle()
                .frame(width: 2, height: compactMode ? 29 : 40)
                .background(backgroundColor)
                .overlay(backgroundColor)

            Button(action: { handleVersionTap() }) {
                Text(versionAbbreviation)
                    .font(.system(size: compactMode ? 10 : 14, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .frame(minWidth: compactMode ? 30 : 36)
                    .frame(height: compactMode ? 29 : 40)
                    .padding(.leading, compactMode ? 12 : 14)
                    .padding(.trailing, compactMode ? 14 : 16)
            }
            .buttonStyle(PlainButtonStyle())
            .clipShape(HalfPillShape(side: .right))
        }
        .background(buttonColor)
        .clipShape(Capsule())
        .padding(.bottom, 2)
        .frame(height: compactMode ? 29 : 40)
    }

    // Custom shape for half-pill sides
    private enum HalfPillSide { case left, right }
    private struct HalfPillShape: Shape {
        let side: HalfPillSide
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let radius = rect.height / 2
            switch side {
            case .left:
                path.addArc(center: CGPoint(x: radius, y: rect.midY), radius: radius, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.closeSubpath()
            case .right:
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
                path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.midY), radius: radius, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
            return path
        }
    }

}

#Preview {
    BibleReaderHalfPillPickersView(
        bookAndChapter: "Genesis 1",
        versionAbbreviation: "KJV",
        handleChapterTap: {},
        handleVersionTap: {},
        foregroundColor: .black,
        buttonColor: .white,
        backgroundColor: .gray,
        compactMode: false
    )
    .padding()
    .background(.gray)
}
