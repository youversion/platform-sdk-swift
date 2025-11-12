import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public class BibleTextNode {
    private let name: String
    public var text: String
    public var children: [BibleTextNode]
    public var classes: [String]
    public var attributes: [String: String]
    public var textSegments: [String]

    init(name: String, text: String = "", children: [BibleTextNode] = [], classes: [String] = [], attributes: [String: String] = [:]) {
        self.name = name
        self.text = text
        self.children = children
        self.classes = classes
        self.attributes = attributes
        self.textSegments = []
    }

    public var type: BibleTextNodeType {
        switch name {
        case "div": return .block
        case "block": return .block
        case "table": return .table
        case "tr": return .row
        case "td": return .cell
        case "text": return .text
        case "span": return .span
        case "root": return .root

        default:
            fatalError("Unknown node type: \(name)")
        }
    }

    public static func parse(_ html: String) throws -> BibleTextNode? {
        let sanitized = sanitizeHTMLForXML(html)
        guard let data = sanitized.data(using: .utf8) else {
            return nil
        }
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false

        if parser.parse() {
            return delegate.parsedRoot
        } else if let error = parser.parserError {
            throw error
        } else {
            return nil
        }
    }

    /// Best-effort transform to make HTML acceptable to XMLParser.
    private static func sanitizeHTMLForXML(_ html: String) -> String {
        // Ensure a single XML root element
        var s = html

        // Self-close common void elements if they appear unclosed
        s = s.replacingOccurrences(of: "<br>", with: "<br/>")
            .replacingOccurrences(of: "<br >", with: "<br/>")
            .replacingOccurrences(of: "<br />", with: "<br/>")

        // Decode common HTML named entities to Unicode characters XML can handle
        let entityMap: [String: String] = [
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&rsquo;": "’",
            "&lsquo;": "‘",
            "&rdquo;": "”",
            "&ldquo;": "“",
            "&copy;": "©",
            "&trade;": "™"
        ]
        for (k, v) in entityMap {
            s = s.replacingOccurrences(of: k, with: v)
        }

        // Wrap with a root element to guarantee a single top-level node
        return "<root>\n" + s + "\n</root>"
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private let parserRoot = BibleTextNode(name: "__parser-root__", classes: [])
        private var stack: [BibleTextNode]

        var parsedRoot: BibleTextNode { parserRoot.children.first ?? parserRoot }

        override init() {
            stack = [parserRoot]
            super.init()
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let classes = attributeDict["class"]?
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init) ?? []
            let filteredAttributes = attributeDict.reduce(into: [String: String]()) { partialResult, entry in
                if entry.key != "class" {
                    partialResult[entry.key] = entry.value
                }
            }
            let node = BibleTextNode(name: elementName, classes: classes, attributes: filteredAttributes)
            stack.last?.children.append(node)
            stack.append(node)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            let collapsed = string.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let core = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !core.isEmpty else {
                return
            }
            let leadingSpace = string.first?.isWhitespace == true
            let trailingSpace = string.last?.isWhitespace == true
            var segment = core
            if leadingSpace {
                segment = " " + segment
            }
            if trailingSpace {
                segment += " "
            }
            guard let current = stack.last else {
                return
            }

            if let lastChild = current.children.last, lastChild.type == .text {
                lastChild.textSegments.append(segment)
                let joined = lastChild.textSegments.joined()
                lastChild.text = joined
                lastChild.textSegments = joined.isEmpty ? [] : [joined]
            } else {
                let textNode = BibleTextNode(name: "text")
                textNode.textSegments = [segment]
                textNode.text = segment
                current.children.append(textNode)
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            _ = stack.popLast()
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
