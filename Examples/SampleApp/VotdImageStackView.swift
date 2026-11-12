import SwiftUI
import YouVersionPlatformCore

/// A moderately complex example widget that lets users tap or swipe through several images in a shuffling stack.
/// It makes no YouVersionPlatform API calls; it demonstrates a SwiftUI approach to presenting supplied image data,
/// using `VotdImageView` for the selected image and decorative previews behind it. Supply a nonempty image array.
struct VotdImageStackView: View {
    let images: [YouVersionImage]
    var onSelectionChange: ((YouVersionImage) -> Void)?
    var onImageTap: ((YouVersionImage) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var flightsByID: [String: CardFlight] = [:]
    @State private var shuffleCount = 0
    @State private var selectedImageID: String?

    private static let visibleCardCount = 3

    private var selectedIndex: Int {
        images.firstIndex { $0.id == selectedImageID } ?? 0
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
                        VotdImageView(image: image, presentation: cardDepth == 0 ? .standard : .decorative) {
                            guard images[selectedIndex].id == image.id && dragOffset == .zero else {
                                return
                            }
                            if onImageTap != nil {
                                onImageTap?(image)
                            } else {
                                shuffle(toward: -1, width: geometry.size.width)
                            }
                        }
                        .scaleEffect(1 - Double(stackDepth) * 0.035)
                        .rotationEffect(.degrees(
                            isOnTop ? Double(offset.width / 24) : restingAngle
                        ))
                        .offset(
                            x: offset.width + (stackDepth == 1 ? 7 : -Double(stackDepth) * 3),
                            y: offset.height + Double(stackDepth) * 6
                        )
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
                        .opacity(flight?.isReturning == true && cardDepth >= Self.visibleCardCount ? 0 : 1)
                        .zIndex(flight?.zIndex ?? -Double(cardDepth))
                        .accessibilityIdentifier("votd.image.\(cardDepth)")
                        .accessibilityHidden(cardDepth != 0)
                        .simultaneousGesture(cardDepth == 0 && images.count > 1 ? swipeGesture(for: image.id, width: geometry.size.width) : nil)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(0.85, contentMode: .fit)

            HStack(spacing: 8) {
                ForEach(indicatorImages) { image in
                    Circle()
                        .fill(image.id == images[selectedIndex].id ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            
            Text(String(
                format: images.count > 1 && onImageTap == nil
                ? String(localized: "votd.image_position_hint")
                : String(localized: "votd.image_position"),
                selectedIndex + 1,
                images.count
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("votd.imagePosition")
        }
        .onChange(of: images[selectedIndex].id, initial: true) {
            onSelectionChange?(images[selectedIndex])
        }
        .onChange(of: isDragging) {
            if !isDragging {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
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
                guard !reduceMotion && images[selectedIndex].id == id && abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                dragOffset = CGSize(width: value.translation.width, height: value.translation.height * 0.15)
            }
            .onEnded { value in
                guard images[selectedIndex].id == id else {
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
        let currentID = images[selectedIndex].id
        let nextIndex = (selectedIndex + 1) % images.count
        let nextID = images[nextIndex].id
        var transaction = Transaction()
        transaction.disablesAnimations = true
        if reduceMotion {
            withTransaction(transaction) {
                flightsByID.removeAll()
                dragOffset = .zero
                selectedImageID = nextID
            }
            return
        }
        let flightID = UUID()
        shuffleCount += 1
        withTransaction(transaction) {
            flightsByID[nextID] = nil
            flightsByID[currentID] = CardFlight(id: flightID, order: shuffleCount, offset: dragOffset)
            dragOffset = .zero
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2), completionCriteria: .removed) {
            selectedImageID = nextID
            flightsByID[currentID]?.offset = CGSize(width: direction * (width + 24), height: 12)
        } completion: {
            guard flightsByID[currentID]?.id == flightID else {
                return
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3), completionCriteria: .removed) {
                flightsByID[currentID]?.isReturning = true
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
