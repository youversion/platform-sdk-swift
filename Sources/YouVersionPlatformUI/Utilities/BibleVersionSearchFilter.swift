import YouVersionPlatformCore

func filteredBibleVersions(_ versions: [BibleVersion], matching searchText: String) -> [BibleVersion] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
        return versions
    }
    return versions.filter { version in
        let title = version.title ?? ""
        let abbr = version.abbreviation ?? String(version.id)
        let lang = version.languageTag ?? ""
        return title.localizedCaseInsensitiveContains(query) ||
            abbr.localizedCaseInsensitiveContains(query) ||
            lang.localizedCaseInsensitiveContains(query)
    }
}
