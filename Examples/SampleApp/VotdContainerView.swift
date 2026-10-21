import SwiftUI
import YouVersionPlatform

struct VotdContainerView: View {
    @State private var showsImages = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("Verse of the Day presentation", selection: $showsImages) {
                    Text("VOTD Card").tag(false)
                    Text("VOTD Image").tag(true)
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
                Text("VERSE OF THE DAY")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Group {
                    if let artwork {
                        Text(artwork.title)
                    } else {
                        Text("Verse of the Day")
                    }
                }
                .font(.headline)
            }

            VotdDatePickerView(selectedDate: $selectedDate)

            if let artwork {
                if artwork.images.isEmpty {
                    Text("(No images are available)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    VotdImageStackView(images: artwork.images)
                        .id(selectedDate)
                }
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load images", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try again") {
                        Task { await loadImages(for: selectedDate) }
                    }
                }
            } else {
                ProgressView("Loading images…")
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
                collection.images
            )
        } catch {
            guard !Task.isCancelled && selectedDate == date else {
                return
            }
            errorMessage = String(localized: "Check your connection and try again.")
        }
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
                Label("Previous day", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("votd.previousDay")

            Button {
                showsDatePicker = true
            } label: {
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("votd.date")
            .popover(isPresented: $showsDatePicker) {
                DatePicker("Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
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
                Label("Next day", systemImage: "chevron.right")
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

private struct VotdImageStackView: View {
    let images: [YouVersionImage]

    @GestureState private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var flightsByID: [String: CardFlight] = [:]
    @State private var shuffleCount = 0
    @State private var selectedIndex = 0

    private static let visibleCardCount = 3

    private var selectedID: String {
        images[selectedIndex].id
    }

    private var visibleImages: [YouVersionImage] {
        images.filter { depth(for: $0.id) < Self.visibleCardCount || flightsByID[$0.id] != nil }
    }

    private var indicatorImages: [YouVersionImage] {
        let start = max(0, min(selectedIndex - 3, images.count - 7))
        return Array(images.dropFirst(start).prefix(7))
    }

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geometry in
                ZStack {
                    ForEach(visibleImages) { image in
                        let cardDepth = depth(for: image.id)
                        let flight = flightsByID[image.id]
                        let offset = flight?.offset ?? (cardDepth == 0 ? dragOffset : .zero)
                        let stackDepth = flight?.isReturning == false ? 0 : min(cardDepth, Self.visibleCardCount - 1)
                        let restingAngle = (images.firstIndex { $0.id == image.id } ?? 0).isMultiple(of: 2) ? 4.0 : -5.0
                        let isOnTop = cardDepth == 0 || flight?.isReturning == false
                        VotdArtworkView(image: image, canAdvance: images.count > 1) {
                            guard selectedID == image.id && dragOffset == .zero else {
                                return
                            }
                            shuffle(toward: -1, width: geometry.size.width)
                        }
                            .frame(width: max(geometry.size.width - 48, 1), height: geometry.size.height - 40)
                            .scaleEffect(1 - Double(stackDepth) * 0.035)
                            .rotationEffect(.degrees(
                                isOnTop ? Double(offset.width / 24) : restingAngle
                            ))
                            .offset(
                                x: offset.width + (stackDepth == 1 ? 7 : -Double(stackDepth) * 3),
                                y: offset.height + Double(stackDepth) * 6
                            )
                            .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
                            .zIndex(flight?.zIndex ?? -Double(cardDepth))
                            .allowsHitTesting(cardDepth == 0)
                            .accessibilityIdentifier("votd.image.\(cardDepth)")
                            .simultaneousGesture(cardDepth == 0 && images.count > 1 ? swipeGesture(for: image.id, width: geometry.size.width) : nil)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(0.85, contentMode: .fit)

            HStack(spacing: 8) {
                ForEach(indicatorImages) { image in
                    Circle()
                        .fill(image.id == selectedID ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }

            Text(images.count > 1
                 ? String(localized: "\(selectedIndex + 1) of \(images.count) · Tap or swipe for more")
                 : String(localized: "\(selectedIndex + 1) of \(images.count)"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("votd.imagePosition")
        }
        .onChange(of: isDragging) {
            if !isDragging {
                withAnimation(.spring(duration: 0.3)) {
                    dragOffset = .zero
                }
            }
        }
        .onDisappear {
            flightsByID.removeAll()
            dragOffset = .zero
        }
    }

    private func depth(for id: String) -> Int {
        let index = images.firstIndex { $0.id == id } ?? selectedIndex
        return (index - selectedIndex + images.count) % max(images.count, 1)
    }

    private func swipeGesture(for id: String, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .updating($isDragging) { _, isDragging, _ in
                isDragging = true
            }
            .onChanged { value in
                guard selectedID == id && abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                dragOffset = CGSize(width: value.translation.width, height: value.translation.height * 0.15)
            }
            .onEnded { value in
                guard selectedID == id else {
                    return
                }
                let horizontalDistance = value.predictedEndTranslation.width
                if abs(value.translation.width) > abs(value.translation.height) && abs(horizontalDistance) > width * 0.25 {
                    shuffle(toward: horizontalDistance < 0 ? -1 : 1, width: width)
                }
            }
    }

    private func shuffle(toward direction: CGFloat, width: CGFloat) {
        guard images.count > 1 else {
            return
        }
        let currentID = selectedID
        let nextIndex = (selectedIndex + 1) % images.count
        let nextID = images[nextIndex].id
        let flightID = UUID()
        shuffleCount += 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            flightsByID[nextID] = nil
            flightsByID[currentID] = CardFlight(id: flightID, order: shuffleCount, offset: dragOffset)
            dragOffset = .zero
        }
        withAnimation(.easeOut(duration: 0.2), completionCriteria: .removed) {
            selectedIndex = nextIndex
            flightsByID[currentID]?.offset = CGSize(width: direction * (width + 24), height: 12)
        } completion: {
            guard flightsByID[currentID]?.id == flightID else {
                return
            }
            withTransaction(transaction) {
                flightsByID[currentID]?.isReturning = true
            }
            withAnimation(.spring(duration: 0.38, bounce: 0.12), completionCriteria: .removed) {
                flightsByID[currentID]?.offset = .zero
            } completion: {
                guard flightsByID[currentID]?.id == flightID else {
                    return
                }
                flightsByID[currentID] = nil
            }
        }
    }

    private struct CardFlight: Equatable {
        let id: UUID
        let order: Int
        var offset: CGSize
        var isReturning = false

        var zIndex: Double {
            isReturning ? -Double(order + VotdImageStackView.visibleCardCount) : Double(order)
        }
    }
}

private struct VotdArtworkView: View {
    let image: YouVersionImage
    let canAdvance: Bool
    let onAdvance: () -> Void

    @State private var retryCount = 0

    var body: some View {
        AsyncImage(url: image.imageURL) { phase in
            switch phase {
            case .success(let artwork):
                Button(action: onAdvance) {
                    artwork.resizable().scaledToFit()
                }
                .buttonStyle(VotdArtworkButtonStyle())
                .disabled(!canAdvance)
            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("Image couldn't load")
                        .font(.callout)
                    Button("Retry image") { retryCount += 1 }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .id(retryCount)
        .aspectRatio(CGFloat(max(image.width, 1)) / CGFloat(max(image.height, 1)), contentMode: .fit)
        .background(.quaternary)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 18))
    }
}

private struct VotdArtworkButtonStyle: PrimitiveButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect)
            .onTapGesture {
                if isEnabled {
                    configuration.trigger()
                }
            }
    }
}
