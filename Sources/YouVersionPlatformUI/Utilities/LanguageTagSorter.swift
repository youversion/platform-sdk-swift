func sortedUniqueLanguageTags(_ tags: [String], languageName: (String) -> String) -> [String] {
    let unique = Array(Set(tags))
    let names = Dictionary(uniqueKeysWithValues: unique.map { ($0, languageName($0)) })
    return unique.sorted {
        names[$0, default: $0].localizedCaseInsensitiveCompare(names[$1, default: $1]) == .orderedAscending
    }
}

func filterLanguageTags(_ tags: [String], matching searchText: String, languageName: (String) -> String) -> [String] {
    guard !searchText.isEmpty else {
        return tags
    }
    return tags.filter {
        $0.localizedCaseInsensitiveContains(searchText) ||
        languageName($0).localizedCaseInsensitiveContains(searchText)
    }
}
