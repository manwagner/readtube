"""Tests for prompts module."""

from readtube.prompts import get_prompt, SYSTEM_PROMPT


class TestGetPrompt:
    def test_article_mode(self):
        system, user = get_prompt("article", "transcript text", "Title", "Channel")
        assert system == SYSTEM_PROMPT
        assert "Title" in user
        assert "Channel" in user
        assert "transcript text" in user

    def test_tldr_mode(self):
        system, user = get_prompt("tldr", "transcript text", "Title", "Channel")
        assert "3-5" in user
        assert "bullet" in user

    def test_takeaways_mode(self):
        system, user = get_prompt("takeaways", "transcript text", "Title", "Channel")
        assert "takeaways" in user.lower()

    def test_with_chapters(self):
        system, user = get_prompt(
            "article", "transcript", "Title", "Channel",
            chapters_text="- [0:00] Intro\n- [5:00] Main",
        )
        assert "Intro" in user
        assert "Main" in user

    def test_with_chapter_structure(self):
        system, user = get_prompt(
            "article", "transcript", "Title", "Channel",
            has_chapter_structure=True,
        )
        assert "## headings" in user

    def test_with_timestamps(self):
        system, user = get_prompt(
            "article", "transcript", "Title", "Channel",
            timestamps=True,
        )
        assert "timestamp" in user.lower() or "MM:SS" in user

    def test_transcript_truncation(self):
        long_transcript = "x" * 100000
        _, user = get_prompt("article", long_transcript, "T", "C")
        # Should be truncated to 50000
        assert len(user) < 60000
