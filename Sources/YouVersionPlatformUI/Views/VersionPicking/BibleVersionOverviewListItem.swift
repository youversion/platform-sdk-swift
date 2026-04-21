import SwiftUI
import YouVersionPlatformCore

struct BibleVersionOverviewListItem: View, AbbreviationSplitting {
    @Environment(BibleVersionsViewModel.self) private var viewModel
    let item: BibleVersion

    var body: some View {
        HStack(spacing: 12) {
            // Rounded square with abbreviation
            VStack(spacing: 0) {
                let abbreviation = item.localizedAbbreviation ?? item.abbreviation ?? String(item.id)
                let (letters, numbers) = splitAbbreviation(abbreviation)

                Text(letters)
                    .font(YouVersionFonts.preferredBibleTextFont(size: 15))
                    .foregroundStyle(viewModel.readerTextPrimaryColor)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if !numbers.isEmpty {
                    Text(numbers)
                        .font(YouVersionFonts.preferredBibleTextFont(size: 10).weight(.semibold))
                        .foregroundStyle(viewModel.readerTextPrimaryColor)
                        .lineLimit(1)
                }
            }
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(viewModel.readerButtonPrimaryColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(viewModel.readerBorderPrimaryColor, lineWidth: 1)
                    )
            )

            // Version title
            Text(item.localizedTitle ?? item.title ?? item.localizedAbbreviation ?? item.abbreviation ?? String(item.id))
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
        BibleVersionOverviewListItem(item: BibleVersion.preview)
            .environment(BibleVersionsViewModel.preview)
        Divider()
    }
}
