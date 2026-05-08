import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Parses YouVersion Bible chapter HTML into an immutable `BibleTextNode` tree.
struct BibleTextNodeParser {

    static func parse(_ html: String) throws -> BibleTextNode {
        let sanitized = sanitizeForXML(html: html)
        guard let data = sanitized.data(using: .utf8) else {
            throw BibleTextNodeParserError.invalidEncoding
        }
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false

        if parser.parse(), let root = delegate.parsedRoot {
            return root
        } else if let error = parser.parserError {
            throw error
        } else {
            throw BibleTextNodeParserError.emptyContent
        }
    }

    /// Best-effort transform to make HTML acceptable to XMLParser.
    private static func sanitizeForXML(html: String) -> String {
        var s = html

        // Self-close common void elements if they appear unclosed
        s = s.replacingOccurrences(of: "<br>", with: "<br/>")
            .replacingOccurrences(of: "<br >", with: "<br/>")
            .replacingOccurrences(of: "<br />", with: "<br/>")

        // Decode common HTML named entities to Unicode characters XML can handle
        let replacements: [String: String] = [
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
        for (k, v) in replacements {
            s = s.replacingOccurrences(of: k, with: v)
        }

        // Wrap with a root element to guarantee a single top-level node
        return "<root>\n" + s + "\n</root>"
    }

    /// Builds the BibleTextNode tree bottom-up so all nodes are immutable once created.
    private final class ParserDelegate: NSObject, XMLParserDelegate {
        /// A frame on the parse stack representing an open element whose children
        /// are still being collected.
        private struct Frame {
            let name: String
            let classes: [String]
            let attributes: [String: String]
            var children: [BibleTextNode]
        }

        private var stack: [Frame]

        var parsedRoot: BibleTextNode? {
            stack.first?.children.first
        }

        override init() {
            stack = [Frame(name: "__parser-root__", classes: [], attributes: [:], children: [])]
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
            stack.append(Frame(name: elementName, classes: classes, attributes: filteredAttributes, children: []))
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard !stack.isEmpty else {
                return
            }

            let segment = string.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            guard !segment.isEmpty else {
                return
            }

            let frameIndex = stack.count - 1

            if segment == " " {
                guard let previousChild = stack[frameIndex].children.last else {
                    return
                }
                guard previousChild.type == .span || previousChild.type == .text else {
                    return
                }
            }

            if let lastChild = stack[frameIndex].children.last, lastChild.type == .text {
                let joined = (lastChild.text + segment)
                    .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
                guard !joined.isEmpty else {
                    return
                }
                // Replace the last text node with an updated version
                stack[frameIndex].children[stack[frameIndex].children.count - 1] = BibleTextNode(
                    name: "text",
                    text: joined,
                    textSegments: [joined]
                )
            } else {
                stack[frameIndex].children.append(
                    BibleTextNode(name: "text", text: segment, textSegments: [segment])
                )
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            guard let frame = stack.popLast() else {
                return
            }
            let node = BibleTextNode(
                name: frame.name,
                children: frame.children,
                classes: frame.classes,
                attributes: frame.attributes
            )
            if !stack.isEmpty {
                stack[stack.count - 1].children.append(node)
            }
        }
    }
}

enum BibleTextNodeParserError: Error {
    case invalidEncoding
    case emptyContent
}
