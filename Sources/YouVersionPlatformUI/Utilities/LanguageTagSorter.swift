func sortedUniqueLanguageTags(_ tags: [String], languageName: (String) -> String) -> [String] {
    let unique = Array(Set(tags))
    let names = Dictionary(uniqueKeysWithValues: unique.map { ($0, languageName($0)) })
    return unique.sorted {
        names[$0, default: $0].localizedCaseInsensitiveCompare(names[$1, default: $1]) == .orderedAscending
    }
}

func filteredLanguageTags(_ tags: [String], matching searchText: String, languageName: (String) -> String) -> [String] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
        return tags
    }
    return tags.filter {
        $0.localizedCaseInsensitiveContains(query) ||
        languageName($0).localizedCaseInsensitiveContains(query)
    }
}
