import SwiftUI

/// The blocks a rendered chapter can scroll to, published up from
/// `BibleTextView` so the reader can scroll to a verse once its block exists.
public struct ChapterScrollAnchors: Equatable {
    /// The chapter these blocks belong to.
    public let chapter: Int

    /// The first verse of each block, in render order. Each block is tagged with its
    /// first verse as its `.id`.
    public let blockFirstVerses: [Int]

    public init(chapter: Int, blockFirstVerses: [Int]) {
        self.chapter = chapter
        self.blockFirstVerses = blockFirstVerses
    }

    /// The `.id` of the block containing `verse`.
    public func blockFirstVerse(forTargetVerse verse: Int) -> Int? {
        blockFirstVerses.last(where: { $0 <= verse })
    }
}

public struct ChapterScrollAnchorsKey: PreferenceKey {
    public static var defaultValue: ChapterScrollAnchors? { nil }

    public static func reduce(value: inout ChapterScrollAnchors?, nextValue: () -> ChapterScrollAnchors?) {
        value = nextValue() ?? value
    }
}
