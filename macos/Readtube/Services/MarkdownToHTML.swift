import Foundation
import Markdown

/// Convert markdown text to HTML using apple/swift-markdown.
enum MarkdownToHTML {
    static func convert(_ markdown: String) -> String {
        let document = Document(parsing: markdown)
        var renderer = HTMLRenderer()
        return renderer.render(document)
    }
}

/// Walks the Markdown AST and emits HTML.
private struct HTMLRenderer: MarkupWalker {
    private var html = ""

    mutating func render(_ document: Document) -> String {
        html = ""
        visit(document)
        return html
    }

    // MARK: - Block elements

    mutating func visitHeading(_ heading: Heading) {
        let tag = "h\(heading.level)"
        html += "<\(tag)>"
        descendInto(heading)
        html += "</\(tag)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        html += "<p>"
        descendInto(paragraph)
        html += "</p>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        html += "<blockquote>\n"
        descendInto(blockQuote)
        html += "</blockquote>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        html += "<ol>\n"
        descendInto(orderedList)
        html += "</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        html += "<ul>\n"
        descendInto(unorderedList)
        html += "</ul>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) {
        html += "<li>"
        descendInto(listItem)
        html += "</li>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let lang = codeBlock.language ?? ""
        let escaped = escapeHTML(codeBlock.code)
        if lang.isEmpty {
            html += "<pre><code>\(escaped)</code></pre>\n"
        } else {
            html += "<pre><code class=\"language-\(escapeHTML(lang))\">\(escaped)</code></pre>\n"
        }
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        html += "<hr>\n"
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) {
        html += htmlBlock.rawHTML
    }

    // MARK: - Inline elements

    // Use fully qualified Markdown.Text to avoid conflict with SwiftUI.Text
    mutating func visitText(_ text: Markdown.Text) {
        html += escapeHTML(text.string)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        html += "<em>"
        descendInto(emphasis)
        html += "</em>"
    }

    mutating func visitStrong(_ strong: Strong) {
        html += "<strong>"
        descendInto(strong)
        html += "</strong>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        html += "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitLink(_ link: Markdown.Link) {
        let dest = link.destination ?? ""
        html += "<a href=\"\(escapeHTML(dest))\">"
        descendInto(link)
        html += "</a>"
    }

    mutating func visitImage(_ image: Markdown.Image) {
        let src = image.source ?? ""
        let alt = image.plainText
        html += "<img src=\"\(escapeHTML(src))\" alt=\"\(escapeHTML(alt))\">"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        html += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        html += "<br>\n"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        html += inlineHTML.rawHTML
    }

    // MARK: - Helpers

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
