"""Tests for render module."""

import tempfile
from pathlib import Path

import pytest
from readtube.render import render_output


class TestRenderMarkdown:
    def test_returns_content_for_stdout(self):
        result = render_output(
            "# Hello\n\nWorld", "Title", "Channel",
            "https://youtube.com/watch?v=abc",
        )
        assert "# Hello" in result
        assert "World" in result

    def test_writes_to_file(self):
        with tempfile.NamedTemporaryFile(suffix=".md", delete=False) as f:
            path = f.name

        result = render_output(
            "# Hello", "Title", "Channel",
            "https://youtube.com/watch?v=abc",
            output_path=path,
        )
        assert result == path
        content = Path(path).read_text()
        assert "# Hello" in content
        Path(path).unlink()

    def test_detects_format_from_extension(self):
        with tempfile.NamedTemporaryFile(suffix=".md", delete=False) as f:
            path = f.name

        render_output("# Test", "T", "C", "url", output_path=path)
        assert Path(path).exists()
        Path(path).unlink()


class TestRenderHTML:
    def test_returns_html_string(self):
        try:
            import markdown
        except ImportError:
            pytest.skip("markdown not installed")

        result = render_output(
            "# Hello\n\nWorld", "Title", "Channel",
            "https://youtube.com/watch?v=abc",
            fmt="html",
        )
        assert "<html" in result
        assert "Hello" in result
        assert "Title" in result

    def test_writes_html_file(self):
        try:
            import markdown
        except ImportError:
            pytest.skip("markdown not installed")

        with tempfile.NamedTemporaryFile(suffix=".html", delete=False) as f:
            path = f.name

        render_output(
            "# Hello", "Title", "Channel", "url",
            output_path=path, fmt="html",
        )
        content = Path(path).read_text()
        assert "<html" in content
        Path(path).unlink()

    def test_html_escapes_title(self):
        try:
            import markdown
        except ImportError:
            pytest.skip("markdown not installed")

        result = render_output(
            "text", 'Title with "quotes" & <tags>', "Channel", "url",
            fmt="html",
        )
        assert "&amp;" in result
        assert "&lt;" in result


class TestRenderEPUB:
    def test_requires_output_path(self):
        from readtube.errors import OutputFormatError
        with pytest.raises(OutputFormatError):
            render_output("# Test", "T", "C", "url", fmt="epub")

    def test_creates_epub(self):
        try:
            from ebooklib import epub
            import markdown
        except ImportError:
            pytest.skip("ebooklib or markdown not installed")

        with tempfile.NamedTemporaryFile(suffix=".epub", delete=False) as f:
            path = f.name

        render_output(
            "# Hello\n\nArticle content", "Title", "Channel", "url",
            output_path=path, fmt="epub",
        )
        assert Path(path).exists()
        assert Path(path).stat().st_size > 0
        Path(path).unlink()


class TestUnsupportedFormat:
    def test_raises_for_unknown_format(self):
        from readtube.errors import OutputFormatError
        with pytest.raises(OutputFormatError):
            render_output("text", "T", "C", "url", fmt="docx")
