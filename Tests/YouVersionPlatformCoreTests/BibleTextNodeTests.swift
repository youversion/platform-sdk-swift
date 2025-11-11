@testable import YouVersionPlatformCore
import Testing

@Test
func testParse_DivSpanStructure() throws {
    let html = "<div><div class=\"q1\"><span class=\"yv-v\" v=\"1\"></span><span class=\"yv-vlbl\">1</span>Praise the <span class=\"nd\">Lord</span>, all you nations;</div></div>"

    let root = try #require(try BibleTextNode.parse(html))
    #expect(root.type == .root)
    #expect(root.children.count == 1)

    let outer = try #require(root.children.first)
    #expect(outer.type == .block)

    let inner = try #require(outer.children.first)
    #expect(inner.type == .block)
    #expect(inner.classes.contains("q1"))

    // children: [span.yv-v, span.yv-vlbl, text("Praise the"), span.nd, text(", all you nations;")]
    #expect(inner.children.count == 5)

    let verseMarker = inner.children[0]
    #expect(verseMarker.type == .span)
    #expect(verseMarker.classes.contains("yv-v"))
    #expect(verseMarker.attributes["v"] == "1")
    #expect(verseMarker.textSegments.isEmpty)

    let verseLabel = inner.children[1]
    #expect(verseLabel.type == .span)
    #expect(verseLabel.classes.contains("yv-vlbl"))
    #expect(verseLabel.children.count == 1)
    let verseLabelText = verseLabel.children[0]
    #expect(verseLabelText.type == .text)
    #expect(verseLabelText.text == "1")

    let textBefore = inner.children[2]
    #expect(textBefore.type == .text)
    #expect(textBefore.text == "Praise the ")  // trailing space preserved from HTML

    let nameDivine = inner.children[3]
    #expect(nameDivine.type == .span)
    #expect(nameDivine.classes.contains("nd"))
    #expect(nameDivine.children.count == 1)
    let nameDivineText = nameDivine.children[0]
    #expect(nameDivineText.type == .text)
    #expect(nameDivineText.text == "Lord")

    let textAfter = inner.children[4]
    #expect(textAfter.type == .text)
    #expect(textAfter.text == ", all you nations;")
}

@Test
func testParse_GenesisIntroContainsText() throws {
    let html = """
    <div>
      <div class="pi">
        <span class="yv-v" v="1"></span>
        <span class="yv-vlbl">1</span>
        In the beginning, God created the heavens and the earth.
      </div>
    </div>
    """

    let root = try #require(try BibleTextNode.parse(html))

    func collectTexts(_ node: BibleTextNode) -> [String] {
        var texts: [String] = []
        if node.type == .text {
            let trimmed = node.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                texts.append(trimmed)
            }
        }
        for child in node.children {
            texts.append(contentsOf: collectTexts(child))
        }
        return texts
    }

    let texts = collectTexts(root)
    #expect(texts.contains("In the beginning, God created the heavens and the earth."))
}
