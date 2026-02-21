import XCTest

final class MarkdownToHTMLTests: XCTestCase {

    // MARK: - Headings

    func testHeadings() {
        let html = MarkdownToHTML.convert("# Title")
        XCTAssertTrue(html.contains("<h1>Title</h1>"))
    }

    func testHeadingLevels() {
        XCTAssertTrue(MarkdownToHTML.convert("## Sub").contains("<h2>Sub</h2>"))
        XCTAssertTrue(MarkdownToHTML.convert("### Sub2").contains("<h3>Sub2</h3>"))
    }

    // MARK: - Paragraphs

    func testParagraph() {
        let html = MarkdownToHTML.convert("Hello world")
        XCTAssertTrue(html.contains("<p>Hello world</p>"))
    }

    func testMultipleParagraphs() {
        let html = MarkdownToHTML.convert("First\n\nSecond")
        XCTAssertTrue(html.contains("<p>First</p>"))
        XCTAssertTrue(html.contains("<p>Second</p>"))
    }

    // MARK: - Inline formatting

    func testBold() {
        let html = MarkdownToHTML.convert("**bold**")
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
    }

    func testItalic() {
        let html = MarkdownToHTML.convert("*italic*")
        XCTAssertTrue(html.contains("<em>italic</em>"))
    }

    func testInlineCode() {
        let html = MarkdownToHTML.convert("`code`")
        XCTAssertTrue(html.contains("<code>code</code>"))
    }

    // MARK: - Links and images

    func testLink() {
        let html = MarkdownToHTML.convert("[text](https://example.com)")
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">text</a>"))
    }

    func testImage() {
        let html = MarkdownToHTML.convert("![alt](https://example.com/img.jpg)")
        XCTAssertTrue(html.contains("<img src=\"https://example.com/img.jpg\" alt=\"alt\">"))
    }

    // MARK: - Lists

    func testUnorderedList() {
        let html = MarkdownToHTML.convert("- item 1\n- item 2")
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>"))
        XCTAssertTrue(html.contains("item 1"))
        XCTAssertTrue(html.contains("item 2"))
    }

    func testOrderedList() {
        let html = MarkdownToHTML.convert("1. first\n2. second")
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("first"))
        XCTAssertTrue(html.contains("second"))
    }

    // MARK: - Block elements

    func testBlockquote() {
        let html = MarkdownToHTML.convert("> quote")
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("quote"))
    }

    func testCodeBlock() {
        let html = MarkdownToHTML.convert("```\ncode\n```")
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("code"))
    }

    func testCodeBlockWithLanguage() {
        let html = MarkdownToHTML.convert("```python\nprint('hi')\n```")
        XCTAssertTrue(html.contains("language-python"))
    }

    func testThematicBreak() {
        let html = MarkdownToHTML.convert("---")
        XCTAssertTrue(html.contains("<hr>"))
    }

    // MARK: - HTML escaping

    func testEscapesAmpersand() {
        let html = MarkdownToHTML.convert("Tom & Jerry")
        XCTAssertTrue(html.contains("&amp;"))
        XCTAssertFalse(html.contains(" & "))
    }

    func testEscapesHTMLInInlineCode() {
        let html = MarkdownToHTML.convert("`<script>alert('xss')</script>`")
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertFalse(html.contains("<script>alert"))
    }

    // MARK: - Empty input

    func testEmptyInput() {
        let html = MarkdownToHTML.convert("")
        XCTAssertTrue(html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Complex document

    func testComplexDocument() {
        let md = """
        # Article Title

        By **Author Name**

        ## Introduction

        This is the *first* paragraph with a [link](https://example.com).

        > An important quote

        ## Code Example

        ```swift
        let x = 42
        ```

        - Point one
        - Point two
        """
        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<h1>Article Title</h1>"))
        XCTAssertTrue(html.contains("<strong>Author Name</strong>"))
        XCTAssertTrue(html.contains("<h2>Introduction</h2>"))
        XCTAssertTrue(html.contains("<em>first</em>"))
        XCTAssertTrue(html.contains("<a href="))
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("language-swift"))
        XCTAssertTrue(html.contains("<ul>"))
    }
}
