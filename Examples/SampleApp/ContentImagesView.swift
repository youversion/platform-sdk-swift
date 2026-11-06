import SwiftUI
import YouVersionPlatform

struct ContentImagesView: View {
    let navigation: BibleReaderNavigation
    let onNavigate: () -> Void
    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var images: [YouVersionImage] = []
    @State private var nextPageToken: String?
    @State private var errorMessage: String?
    @State private var validationMessage: String?
    @State private var isFirstPage = true
    @State private var isLoading = false
    @State private var retryID = UUID()
    @State private var completedRequestID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search by verse reference", text: $query)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { submitSearch() }
                        .accessibilityIdentifier("content.imageSearch")
                    if !query.isEmpty {
                        Button {
                            query = ""
                            submitSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(12)
                .background(.quaternary, in: .capsule)
                if let validationMessage {
                    Text(validationMessage).foregroundStyle(.secondary)
                } else {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.secondary)
                        Button("Retry") { retryID = UUID() }
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(images) { image in
                            NavigationLink {
                                ContentImageView(image: image, navigation: navigation, onNavigate: onNavigate)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    VotdImageView(image: image)
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                    Label(image.passageID, systemImage: "book.closed")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if errorMessage == nil && images.isEmpty {
                        ContentUnavailableView {
                            Label("No images found", systemImage: "photo.on.rectangle")
                        } description: {
                            if !submittedQuery.isEmpty {
                                Text("There are no images for \(submittedQuery)")
                            }
                        }
                    }
                    if nextPageToken != nil && !isLoading {
                        Button("Load more") {
                            isFirstPage = false
                            retryID = UUID()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
        }
        .task(id: retryID) {
            guard completedRequestID != retryID else {
                return
            }
            await loadImages(isFirstPage: isFirstPage)
        }
    }

    private func submitSearch() {
        let passageID = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard passageID.isEmpty || passageID.range(of: #"^[A-Z0-9]+\.[0-9]+\.[0-9]+(?:-[0-9]+)?$"#, options: .regularExpression) != nil else {
            validationMessage = String(localized: "Enter a verse or verse range such as GEN.1.2 or GEN.1.3-5.")
            return
        }
        validationMessage = nil
        isFirstPage = true
        submittedQuery = passageID
        retryID = UUID()
    }

    private func loadImages(isFirstPage: Bool) async {
        let requestID = retryID
        let requestQuery = submittedQuery
        isLoading = true
        errorMessage = nil
        if isFirstPage {
            images = []
            nextPageToken = nil
        }
        defer {
            if requestID == retryID { isLoading = false }
        }
        do {
            let page = try await YouVersionAPI.Images.images(
                passageID: requestQuery.isEmpty ? nil : requestQuery,
                pageSize: 30,
                pageToken: isFirstPage ? nil : nextPageToken
            )
            try Task.checkCancellation()
            guard requestID == retryID && requestQuery == submittedQuery else {
                return
            }
            let existingIDs = Set(images.map(\.id))
            images += page.images.filter { !existingIDs.contains($0.id) }
            nextPageToken = page.nextPageToken
            completedRequestID = requestID
        } catch {
            if !Task.isCancelled && requestID == retryID { errorMessage = error.localizedDescription }
        }
    }
}

struct ContentImageView: View {
    let image: YouVersionImage
    let navigation: BibleReaderNavigation
    let onNavigate: () -> Void
    @State private var images: [YouVersionImage] = []
    @State private var selectedImage: YouVersionImage?
    @State private var title = ""
    @State private var errorMessage: String?
    @State private var retryID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(title.isEmpty ? image.passageID : title).font(.title2.bold())
                VotdImageStackView(images: images.isEmpty ? [image] : images) { selectedImage = $0 }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                    Button("Retry") { retryID = UUID() }
                }
            }
            .padding(20)
        }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar { ShareLink(item: image.url) }
        // The suggested yvFullScreenCover modifier is not defined in this package.
        // swiftlint:disable:next swiftui_fullscreencover
        .fullScreenCover(item: $selectedImage) { selected in
            ContentImageViewer(image: selected, navigation: navigation, onNavigate: onNavigate)
        }
        .task(id: retryID) {
            do {
                async let version = BibleVersionRepository.shared.version(withId: 3034)
                async let page = YouVersionAPI.Images.images(passageID: image.passageID, pageSize: 99)
                let (bibleVersion, firstPage) = try await (version, page)
                try Task.checkCancellation()
                if let reference = bibleVersion.reference(with: image.passageID) {
                    title = bibleVersion.displayTitle(for: reference, includesVersionAbbreviation: false)
                }
                images = [image] + firstPage.images.filter { $0.id != image.id }
                var token = firstPage.nextPageToken
                var visitedTokens: Set<String> = []
                while let pageToken = token {
                    guard visitedTokens.insert(pageToken).inserted else {
                        throw YouVersionAPIError.invalidResponse
                    }
                    let next = try await YouVersionAPI.Images.images(passageID: image.passageID, pageSize: 99, pageToken: pageToken)
                    try Task.checkCancellation()
                    let existingIDs = Set(images.map(\.id))
                    images += next.images.filter { !existingIDs.contains($0.id) }
                    token = next.nextPageToken
                }
                errorMessage = nil
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }
}

private struct ContentImageViewer: View {
    let image: YouVersionImage
    let navigation: BibleReaderNavigation
    let onNavigate: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reference: BibleReference?
    @State private var title = ""
    @State private var errorMessage: String?
    @State private var retryID = UUID()

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close image")
                Spacer()
                ShareLink(item: image.url)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VotdImageView(image: image)
                    Text("Verses in this image").font(.caption)
                    Text(title.isEmpty ? image.passageID : title).font(.title2.bold())
                    if let reference {
                        BibleCardView(reference: reference, fontSize: 18, showVersionPicker: false)
                    }
                    Text(image.attribution).font(.caption).foregroundStyle(.secondary)
                    if let errorMessage {
                        Text(errorMessage).font(.callout)
                        Button("Retry") { retryID = UUID() }
                    }
                }
            }
            Button {
                guard let reference else {
                    return
                }
                navigation.request(reference, showsFullChapter: true)
                dismiss()
                onNavigate()
            } label: {
                Label("Read in Bible", systemImage: "book.closed")
                    .frame(maxWidth: .infinity)
                    .padding(12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(reference == nil)
        }
        .padding(20)
        .background(.black)
        .preferredColorScheme(.dark)
        .task(id: retryID) {
            errorMessage = nil
            do {
                let version = try await BibleVersionRepository.shared.version(withId: 3034)
                try Task.checkCancellation()
                guard let resolved = version.reference(with: image.passageID) else {
                    throw YouVersionAPIError.invalidResponse
                }
                reference = resolved
                title = version.displayTitle(for: resolved, includesVersionAbbreviation: true)
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }
}
