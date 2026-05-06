import YouVersionPlatformCore

func filterBibleVersions(_ versions: [BibleVersion], matching searchText: String) -> [BibleVersion] {
    guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return versions
    }
    let query = searchText.lowercased()
    return versions.filter { version in
        let title = (version.title ?? "").lowercased()
        let abbr = (version.abbreviation ?? String(version.id)).lowercased()
        let lang = (version.languageTag ?? "").lowercased()
        return title.contains(query) || abbr.contains(query) || lang.contains(query)
    }
}
