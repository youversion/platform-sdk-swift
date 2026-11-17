import SwiftUI
import YouVersionPlatform

struct ContentView: View {
    let navigation: BibleReaderNavigation
    let onNavigate: () -> Void
    @Environment(\.locale) private var locale
    @State private var showsImages = false
    @State private var showsLanguages = false
    @State private var language = ContentLanguage(tag: "en")

    // YouVersion Platform is planning to create an API to supply the available content languages.
    // For now, this list can be used: it is the set of languages which have verse images.
    private let availableLanguageTags = ["en", "es", "fr", "de", "it", "ja", "zh", "ru", "pt", "ko", "hi", "ar", "tr", "nl", "sv", "zh-CN", "zh-TW", "zh-HK"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 0) {
                        Button { showsImages = false } label: {
                            Text("Videos")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(showsImages ? Color.secondary : Color(uiColor: .systemBackground))
                                .background(showsImages ? Color.clear : Color.primary, in: .capsule)
                        }
                        .accessibilityAddTraits(showsImages ? [] : .isSelected)
                        Button { showsImages = true } label: {
                            Text("Images")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(showsImages ? Color(uiColor: .systemBackground) : Color.secondary)
                                .background(showsImages ? Color.primary : Color.clear, in: .capsule)
                        }
                        .accessibilityAddTraits(showsImages ? .isSelected : [])
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .padding(3)
                    .background(.quaternary, in: .capsule)
                    .accessibilityIdentifier("content.type")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                ZStack {
                    ContentCollectionsView(language: language)
                        .id(language.tag)
                        .opacity(showsImages ? 0 : 1)
                        .allowsHitTesting(!showsImages)
                        .accessibilityHidden(showsImages)
                    ContentImagesView(language: language, navigation: navigation, onNavigate: onNavigate)
                        .opacity(showsImages ? 1 : 0)
                        .allowsHitTesting(showsImages)
                        .accessibilityHidden(!showsImages)
                }
            }
            .navigationTitle("Content")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsLanguages = true
                    } label: {
                        Label(selectedLanguageName, systemImage: "globe")
                            .labelStyle(ContentLanguageLabelStyle())
                    }
                    .accessibilityLabel(Text(selectedLanguageName))
                    .accessibilityHint("Choose the content language")
                    .accessibilityIdentifier("content.language")
                }
            }
            .sheet(isPresented: $showsLanguages) {
                ContentLanguagePicker(
                    languageTags: availableLanguageTags,
                    selectedLanguageTag: Binding(
                        get: { language.tag },
                        set: { tag in
                            if tag != language.tag {
                                language = ContentLanguage(tag: tag)
                            }
                        }
                    )
                )
            }
        }
    }

    private var selectedLanguageName: String {
        locale.localizedString(forIdentifier: language.tag) ?? language.tag
    }
}
