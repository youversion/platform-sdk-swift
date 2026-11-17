import SwiftUI

struct ContentLanguagePicker: View {
    let languageTags: [String]
    @Binding var selectedLanguageTag: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredLanguageTags, id: \.self) { tag in
                    Button {
                        selectedLanguageTag = tag
                        dismiss()
                    } label: {
                        HStack {
                            Text(languageName(for: tag))
                            Spacer()
                            if tag == selectedLanguageTag {
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(tag == selectedLanguageTag ? .isSelected : [])
                }
            }
            .overlay {
                if filteredLanguageTags.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Search languages")
            .navigationTitle("Content language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.backward") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
    }

    private var filteredLanguageTags: [String] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return languageTags.filter { tag in
            search.isEmpty || languageName(for: tag).localizedStandardContains(search)
                || tag.localizedStandardContains(search)
        }
        .sorted { languageName(for: $0).localizedStandardCompare(languageName(for: $1)) == .orderedAscending }
    }

    private func languageName(for tag: String) -> String {
        locale.localizedString(forIdentifier: tag) ?? tag
    }
}
