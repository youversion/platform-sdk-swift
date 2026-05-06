import YouVersionPlatformCore

func filteredBibleVersions(_ versions: [BibleVersion], matching searchText: String) -> [BibleVersion] {
    guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return versions
    }
    return versions.filter { version in
        let title = version.title ?? ""
        let abbr = version.abbreviation ?? String(version.id)
        let lang = version.languageTag ?? ""
        return title.localizedCaseInsensitiveContains(searchText) ||
            abbr.localizedCaseInsensitiveContains(searchText) ||
            lang.localizedCaseInsensitiveContains(searchText)
    }
}
