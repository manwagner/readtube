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

    // MARK: - Nested formatting

    func testNestedBoldItalic() {
        let html = MarkdownToHTML.convert("***bold and italic***")
        XCTAssertTrue(html.contains("<strong>") || html.contains("<em>"))
    }

    func testBoldInsideItalic() {
        let html = MarkdownToHTML.convert("*italic with **bold** inside*")
        XCTAssertTrue(html.contains("<em>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
    }

    // MARK: - Nested lists

    func testNestedUnorderedList() {
        let md = "- item 1\n  - nested 1\n  - nested 2\n- item 2"
        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("nested 1"))
        XCTAssertTrue(html.contains("nested 2"))
    }

    // MARK: - Line breaks

    func testLineBreakWithTwoSpaces() {
        let md = "line one  \nline two"
        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<br>"))
        XCTAssertTrue(html.contains("line one"))
        XCTAssertTrue(html.contains("line two"))
    }

    func testSoftBreak() {
        let md = "line one\nline two"
        let html = MarkdownToHTML.convert(md)
        // Soft break should NOT produce <br>
        XCTAssertFalse(html.contains("<br>"))
        XCTAssertTrue(html.contains("line one"))
        XCTAssertTrue(html.contains("line two"))
    }

    // MARK: - Edge cases

    func testImageWithNoAlt() {
        let html = MarkdownToHTML.convert("![](https://example.com/img.jpg)")
        XCTAssertTrue(html.contains("<img src=\"https://example.com/img.jpg\""))
        XCTAssertTrue(html.contains("alt=\"\""))
    }

    func testLinkWithEmptyText() {
        let html = MarkdownToHTML.convert("[](https://example.com)")
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">"))
    }

    func testConsecutiveBlockquotes() {
        let md = "> quote one\n\n> quote two"
        let html = MarkdownToHTML.convert(md)
        let blockquoteCount = html.components(separatedBy: "<blockquote>").count - 1
        XCTAssertEqual(blockquoteCount, 2)
    }

    func testMultipleHeadingLevels() {
        let md = "# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6"
        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<h1>H1</h1>"))
        XCTAssertTrue(html.contains("<h2>H2</h2>"))
        XCTAssertTrue(html.contains("<h3>H3</h3>"))
        XCTAssertTrue(html.contains("<h4>H4</h4>"))
        XCTAssertTrue(html.contains("<h5>H5</h5>"))
        XCTAssertTrue(html.contains("<h6>H6</h6>"))
    }

    func testCodeBlockWithoutLanguage() {
        let md = "```\nplain code\n```"
        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertFalse(html.contains("language-"))
        XCTAssertTrue(html.contains("plain code"))
    }

    func testHTMLEscapingInLink() {
        let html = MarkdownToHTML.convert("[click & go](https://example.com?a=1&b=2)")
        XCTAssertTrue(html.contains("click &amp; go"))
        XCTAssertTrue(html.contains("a=1&amp;b=2"))
    }

    func testQuotesInAttribute() {
        let html = MarkdownToHTML.convert("[text](https://example.com/path?q=\"test\")")
        XCTAssertTrue(html.contains("&quot;"))
    }

    func testOnlyWhitespace() {
        let html = MarkdownToHTML.convert("   \n  \n   ")
        XCTAssertTrue(html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testOrderedListStartsAtOne() {
        let md = "1. first\n2. second\n3. third"
        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<li>"))
        XCTAssertTrue(html.contains("first"))
        XCTAssertTrue(html.contains("third"))
    }

    func testLargeDocument() {
        var md = ""
        for i in 1...50 {
            md += "## Section \(i)\n\nThis is paragraph \(i) with **bold** and *italic* text.\n\n"
        }
        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<h2>Section 1</h2>"))
        XCTAssertTrue(html.contains("<h2>Section 50</h2>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>italic</em>"))
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
