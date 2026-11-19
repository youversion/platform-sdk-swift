import Foundation

/// Changes selected fields of an existing note while leaving the others unchanged.
///
/// A partial update needs to distinguish between a field that should not be modified and one
/// whose current value should be removed. A single optional value cannot express both intentions,
/// so nullable fields use an optional ``Field`` with three possible states:
///
/// - Omit the argument, or pass `nil`, to leave the field unchanged. The field is not included
///   in the request.
/// - Pass `.clear` to remove the field's current value. The request includes the field as JSON `null`.
/// - Pass `.value(...)` to replace the field's current value with the supplied value.
///
/// For example, this update removes the title and replaces the tags. The omitted color, references,
/// language, content, and status fields keep their existing values:
///
/// ```swift
/// let update = YouVersionNoteUpdate(
///     title: .clear,
///     tags: .value(["faith", "hope"])
/// )
/// let note = try await YouVersionAPI.Notes.updateNote(id: noteID, update: update)
/// ```
///
/// Passing `title: nil` instead would leave the existing title unchanged. Passing
/// `title: .value("")` would replace it with an empty string, rather than clear it.
///
/// The required note fields, ``content`` and ``status``, cannot be cleared. Omit them to leave
/// them unchanged, or supply a replacement value directly. An update must change at least one field.
public struct YouVersionNoteUpdate: Encodable, Sendable {
    /// A replacement value or explicit null for a nullable note field.
    public struct Field<Value: Encodable & Sendable>: Encodable, Sendable {
        fileprivate let replacement: Value?

        public static var clear: Self { Self(replacement: nil) }

        /// Returns a field that replaces the current value.
        public static func value(_ value: Value) -> Self {
            Self(replacement: value)
        }

        /// Encodes a replacement value or explicit JSON null.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            if let replacement {
                try container.encode(replacement)
            } else {
                try container.encodeNil()
            }
        }
    }

    public let title: Field<String>?
    public let content: String?
    public let color: Field<String>?
    /// Nil leaves the attachment unchanged; `.clear` removes it; `.value` replaces it.
    /// Replacement references must form a nonempty selection in one Bible version, book, and chapter.
    public let references: Field<[BibleReference]>?
    public let languageTag: Field<String>?
    public let tags: Field<[String]>?
    public let status: YouVersionNote.Status?

    /// Creates a partial update. Supply at least one field. Content and status cannot be cleared.
    /// Values use the same format restrictions as `YouVersionNoteCreateRequest`.
    /// For references, nil leaves the attachment unchanged, `.clear` removes it, and `.value([reference])`
    /// replaces it. An empty replacement array is invalid; use `.clear` instead.
    public init(
        title: Field<String>? = nil,
        content: String? = nil,
        color: Field<String>? = nil,
        references: Field<[BibleReference]>? = nil,
        languageTag: Field<String>? = nil,
        tags: Field<[String]>? = nil,
        status: YouVersionNote.Status? = nil
    ) {
        self.title = title
        self.content = content
        self.color = color
        self.references = references
        self.languageTag = languageTag
        self.tags = tags
        self.status = status
    }

    var isEmpty: Bool {
        title == nil && content == nil && color == nil && references == nil
            && languageTag == nil && tags == nil && status == nil
    }

    /// Encodes omitted, cleared, and replaced fields distinctly, validating replacement references.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(color, forKey: .color)
        if let references {
            if let replacement = references.replacement {
                try container.encode(NotePassage(references: replacement), forKey: .references)
            } else {
                try container.encodeNil(forKey: .references)
            }
        }
        try container.encodeIfPresent(languageTag, forKey: .languageTag)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(status, forKey: .status)
    }

    private enum CodingKeys: String, CodingKey {
        case title, content, color, tags, status
        case references = "passage"
        case languageTag = "language_tag"
    }
}
