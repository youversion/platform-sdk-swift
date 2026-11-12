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
/// For example, this update removes the title and replaces the tags. The omitted color, passage,
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
        private let replacement: Value?

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
    public let passage: Field<YouVersionNote.Passage>?
    public let languageTag: Field<String>?
    public let tags: Field<[String]>?
    public let status: YouVersionNote.Status?

    /// Creates a partial update. Supply at least one field. Content and status cannot be cleared.
    /// Values use the same format restrictions as `YouVersionNoteCreateRequest`.
    public init(
        title: Field<String>? = nil,
        content: String? = nil,
        color: Field<String>? = nil,
        passage: Field<YouVersionNote.Passage>? = nil,
        languageTag: Field<String>? = nil,
        tags: Field<[String]>? = nil,
        status: YouVersionNote.Status? = nil
    ) {
        self.title = title
        self.content = content
        self.color = color
        self.passage = passage
        self.languageTag = languageTag
        self.tags = tags
        self.status = status
    }

    var isEmpty: Bool {
        title == nil && content == nil && color == nil && passage == nil
            && languageTag == nil && tags == nil && status == nil
    }

    private enum CodingKeys: String, CodingKey {
        case title, content, color, passage, tags, status
        case languageTag = "language_tag"
    }
}
