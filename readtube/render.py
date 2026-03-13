"""Output rendering: markdown, HTML, EPUB, PDF."""

from __future__ import annotations

import html as html_lib
import os
import tempfile
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from .errors import OutputFormatError
from .themes import THEME_DEFAULT, get_theme


def render_output(
    article_md: str,
    title: str,
    channel: str,
    url: str,
    output_path: Optional[str] = None,
    fmt: Optional[str] = None,
    theme_name: str = "default",
    thumbnail: Optional[str] = None,
) -> Optional[str]:
    """Render article to the appropriate format.

    If output_path is None, returns the content as a string (for stdout).
    If output_path is set, writes to file and returns the path.
    Format is detected from file extension if fmt is None.
    """
    if output_path and not fmt:
        ext = Path(output_path).suffix.lstrip(".")
        fmt = ext if ext else "md"

    if not fmt:
        fmt = "md"

    if fmt == "md":
        if output_path:
            Path(output_path).write_text(article_md, encoding="utf-8")
            return output_path
        return article_md

    if fmt == "html":
        return _render_html(article_md, title, channel, url, output_path, theme_name)

    if fmt == "epub":
        return _render_epub(article_md, title, channel, url, output_path, theme_name, thumbnail)

    if fmt == "pdf":
        return _render_pdf(article_md, title, channel, url, output_path, theme_name, thumbnail)

    raise OutputFormatError(fmt, f"unsupported format: {fmt}")


def _md_to_html(md_text: str) -> str:
    """Convert markdown to HTML."""
    try:
        import markdown
        return markdown.markdown(md_text, extensions=["smarty"])
    except ImportError:
        raise OutputFormatError("html", "markdown package required")


def _escape(value: str) -> str:
    return html_lib.escape(str(value), quote=True)


def _render_html(
    article_md: str,
    title: str,
    channel: str,
    url: str,
    output_path: Optional[str],
    theme_name: str,
) -> str:
    theme = get_theme(theme_name)
    article_html = _md_to_html(article_md)
    safe_title = _escape(title)
    safe_channel = _escape(channel)
    safe_url = _escape(url)
    today = datetime.now().strftime("%B %d, %Y")

    full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{safe_title}</title>
    <style>{theme.css}
    body {{ background: #fafaf8; }}
    .container {{ background: white; box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin: 2em auto; padding: 3em 2em; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="intro">
            <p>Based on <strong>{safe_title}</strong> from <strong>{safe_channel}</strong></p>
        </div>
        {article_html}
        <p class="watch-link">Original video: <a href="{safe_url}">{safe_url}</a></p>
    </div>
</body>
</html>"""

    if output_path:
        Path(output_path).write_text(full_html, encoding="utf-8")
        return output_path
    return full_html


def _render_epub(
    article_md: str,
    title: str,
    channel: str,
    url: str,
    output_path: Optional[str],
    theme_name: str,
    thumbnail: Optional[str] = None,
) -> str:
    try:
        from ebooklib import epub
    except ImportError:
        raise OutputFormatError("epub", "ebooklib package required")

    if not output_path:
        raise OutputFormatError("epub", "output path required for EPUB")

    theme = get_theme(theme_name)
    article_html = _md_to_html(article_md)
    safe_title = _escape(title)
    safe_channel = _escape(channel)
    safe_url = _escape(url)

    book = epub.EpubBook()
    book.set_identifier(f"readtube-{datetime.now().strftime('%Y%m%d%H%M%S')}")
    book.set_title(title)
    book.set_language("en")
    book.add_author(channel)

    # CSS
    css = epub.EpubItem(
        uid="style", file_name="style/typography.css",
        media_type="text/css", content=theme.css,
    )
    book.add_item(css)

    # Cover
    if thumbnail:
        try:
            with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
                urllib.request.urlretrieve(thumbnail, tmp.name)
                with open(tmp.name, "rb") as img:
                    book.set_cover("cover.jpg", img.read())
                os.unlink(tmp.name)
        except Exception:
            pass

    # Chapter
    chapter_content = f"""<html>
<head><title>{safe_title}</title>
<link rel="stylesheet" type="text/css" href="style/typography.css"/></head>
<body>
<div class="intro"><p>Based on <strong>{safe_title}</strong> from <strong>{safe_channel}</strong></p></div>
{article_html}
<p class="watch-link">Original video: {safe_url}</p>
</body></html>"""

    chapter = epub.EpubHtml(title=title[:50], file_name="chapter_1.xhtml", lang="en")
    chapter.content = chapter_content
    chapter.add_item(css)
    book.add_item(chapter)

    book.toc = (chapter,)
    book.add_item(epub.EpubNcx())
    book.add_item(epub.EpubNav())
    book.spine = ["nav", chapter]

    epub.write_epub(output_path, book)
    return output_path


def _render_pdf(
    article_md: str,
    title: str,
    channel: str,
    url: str,
    output_path: Optional[str],
    theme_name: str,
    thumbnail: Optional[str] = None,
) -> str:
    try:
        from weasyprint import HTML
    except ImportError:
        raise OutputFormatError("pdf", "weasyprint package required")

    if not output_path:
        raise OutputFormatError("pdf", "output path required for PDF")

    theme = get_theme(theme_name)
    article_html = _md_to_html(article_md)
    safe_title = _escape(title)
    safe_channel = _escape(channel)
    safe_url = _escape(url)
    today = datetime.now().strftime("%B %d, %Y")

    full_html = f"""<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>{safe_title}</title>
<style>{theme.css}
@page {{ size: A5; margin: 2cm 1.5cm; }}
body {{ font-size: 10pt; max-width: none; padding: 0; }}
h1 {{ font-size: 16pt; }}
h2 {{ font-size: 13pt; }}
</style></head>
<body>
<div class="intro"><p>Based on <strong>{safe_title}</strong> from <strong>{safe_channel}</strong></p></div>
{article_html}
<p class="watch-link">Original video: {safe_url}</p>
</body></html>"""

    HTML(string=full_html).write_pdf(output_path)
    return output_path
