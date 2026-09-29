/// The placement of the reader's chapter and version navigation controls.
public struct BibleReaderNavigationPlacement: Equatable, Sendable {
    /// Places navigation at the top of the reader.
    public static let topBar = BibleReaderNavigationPlacement(isTop: true)

    /// Places navigation at the bottom of the reader. The menu stays at the top.
    public static let bottomBar = BibleReaderNavigationPlacement(isTop: false)

    private let isTop: Bool

}
