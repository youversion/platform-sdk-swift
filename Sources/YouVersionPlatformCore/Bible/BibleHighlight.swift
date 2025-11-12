import Foundation

public struct BibleHighlight: CustomDebugStringConvertible, Sendable, Equatable {
    public let reference: BibleReference
    public let color: String  // a hex value, e.g. "#FF00FF"

    public init(_ reference: BibleReference, color: String) {
        self.reference = reference
        self.color = color
    }

    public var debugDescription: String {
        "\(reference) : \(color)"
    }
}
