import SwiftUI
import YouVersionPlatformCore
import YouVersionPlatformUI

struct BibleVersionOverviewListItem: View, ReaderColors, AbbreviationSplitting {
    @Environment(BibleReaderViewModel.self) private var viewModel
    let item: BibleVersion

    var body: some View {
        HStack(spacing: 12) {
            // Rounded square with abbreviation
            VStack(spacing: 0) {
                let abbreviation = item.localizedAbbreviation ?? item.abbreviation ?? String(item.id)
                let (letters, numbers) = splitAbbreviation(abbreviation)

                Text(letters)
                    .font(ReaderFonts.preferredBibleTextFont(size: 15))
                    .foregroundStyle(viewModel.readerTextPrimaryColor)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if !numbers.isEmpty {
                    Text(numbers)
                        .font(ReaderFonts.preferredBibleTextFont(size: 10).weight(.semibold))
                        .foregroundStyle(viewModel.readerTextPrimaryColor)
                        .lineLimit(1)
                }
            }
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(buttonPrimaryColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(borderPrimaryColor, lineWidth: 1)
                    )
            )

            // Version title
            Text(item.title ?? item.abbreviation ?? String(item.id))
                .font(.body)

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(viewModel.readerTextPrimaryColor)
        }
        .contentShape(Rectangle())
    }

}

#Preview {
    VStack {
        Divider()
        BibleVersionOverviewListItem(
            item: BibleReaderViewModel.preview.permittedVersions.first!
        )
        .environment(BibleReaderViewModel.preview)
        Divider()
    }
}
