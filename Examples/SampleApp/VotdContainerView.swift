import SwiftUI
import YouVersionPlatform

struct VotdContainerView: View {
    @State private var showsImages = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("votd.presentation", selection: $showsImages) {
                    Text("votd.view").tag(false)
                    Text("votd.verse_images").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("votd.presentation")

                if showsImages {
                    VotdImagesView()
                } else {
                    VotdView()
                }
            }
            .frame(maxWidth: 520)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct VotdImagesView: View {
    @State private var selectedDate = Date()
    @State private var artwork: (title: String, images: [YouVersionImage])?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("votd.heading")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Group {
                    if let artwork {
                        Text(artwork.title)
                    } else {
                        Text("votd.title")
                    }
                }
                .font(.headline)
            }

            VotdDatePickerView(selectedDate: $selectedDate)

            if let artwork {
                if let firstImage = artwork.images.first {
                    // Choose for your app whether you want to display a single image like VotdImageView does,
                    // or if you want to show all the available images like VotdImageStackView does.
                    if true {
                        VotdImageStackView(images: artwork.images)
                            .id(selectedDate)
                    } else {
                        VotdImageView(image: firstImage)
                            .accessibilityIdentifier("votd.image")
                    }
                } else {
                    Text("votd.no_images")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("votd.images_load_failed", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("votd.try_again") {
                        Task { await loadImages(for: selectedDate) }
                    }
                }
            } else {
                ProgressView("votd.loading_images")
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task(id: selectedDate) {
            await loadImages(for: selectedDate)
        }
    }

    private func loadImages(for date: Date) async {
        artwork = nil
        errorMessage = nil
        do {
            let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
            async let verse = YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: day)
            async let version = BibleVersionRepository.shared.version(withId: 3034)
            let (verseData, bibleVersion) = try await (verse, version)
            guard let reference = bibleVersion.reference(with: verseData.passageId) else {
                throw YouVersionAPIError.invalidResponse
            }
            let collection = try await YouVersionAPI.Images.images(
                passageID: verseData.passageId,
                languageRanges: [Locale.current.language.languageCode?.identifier ?? "en"]
            )
            try Task.checkCancellation()
            guard selectedDate == date else {
                return
            }
            artwork = (
                bibleVersion.displayTitle(for: reference, includesVersionAbbreviation: false),
                collection.images.map { image in
                    YouVersionImage(
                        id: image.id,
                        url: renditionURL(for: image.url),
                        passageID: image.passageID,
                        attribution: image.attribution,
                        languageTag: image.languageTag,
                        width: image.width,
                        height: image.height,
                        aspectRatio: image.aspectRatio
                    )
                }
            )
        } catch {
            guard !Task.isCancelled && selectedDate == date else {
                return
            }
            errorMessage = String(localized: "votd.check_connection")
        }
    }

    /// Requests the API's `card` rendition for this example, preserving the URL's other query parameters.
    /// Choose `thumb`, `card`, or `full` to suit your app's image size needs, or omit `size` for full size.
    private func renditionURL(for imageURL: URL) -> URL {
        var components = URLComponents(url: imageURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.percentEncodedQueryItems?.filter { $0.name != "size" } ?? []
        components?.percentEncodedQueryItems = queryItems + [URLQueryItem(name: "size", value: "card")]
        return components?.url ?? imageURL
    }
}

private struct VotdDatePickerView: View {
    @Binding var selectedDate: Date
    @State private var showsDatePicker = false

    var body: some View {
        HStack {
            Button {
                changeDate(by: -1)
            } label: {
                Label("votd.previous_day", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("votd.previousDay")

            Button {
                showsDatePicker = true
            } label: {
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("votd.date")
            .popover(isPresented: $showsDatePicker) {
                DatePicker("votd.date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .frame(width: 320)
                    .padding(12)
                    .presentationCompactAdaptation(.popover)
                    .onChange(of: selectedDate) {
                        showsDatePicker = false
                    }
            }

            Button {
                changeDate(by: 1)
            } label: {
                Label("votd.next_day", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
            .accessibilityIdentifier("votd.nextDay")
        }
        .buttonStyle(.plain)
        .background(.quaternary, in: .capsule)
    }

    private func changeDate(by days: Int) {
        if let date = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = date
        }
    }
}
