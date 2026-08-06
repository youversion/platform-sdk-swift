public struct BibleTextNode {
    private let name: String
    public let text: String
    public let children: [BibleTextNode]
    public let classes: [String]
    public let attributes: [String: String]
    public let textSegments: [String]

    init(name: String, text: String = "", children: [BibleTextNode] = [], classes: [String] = [], attributes: [String: String] = [:], textSegments: [String] = []) {
        self.name = name
        self.text = text
        self.children = children
        self.classes = classes
        self.attributes = attributes
        self.textSegments = textSegments
    }

    public init(html: String) throws {
        self = try BibleTextNodeParser.parse(html)
    }

    public var type: BibleTextNodeType {
        switch name {
        case "div", "block": .block
        case "table": .table
        case "tr": .row
        case "td": .cell
        case "text": .text
        case "span": .span
        case "root": .root
        default: fatalError("Unknown node type: \(name)")
        }
    }
}

public enum BibleTextNodeType {
    case block
    case table
    case row
    case cell
    case text
    case span
    case root
}
