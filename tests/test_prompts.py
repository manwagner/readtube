"""Tests for prompts module."""

from readtube.prompts import get_prompt, SYSTEM_PROMPT, _length_instructions, _bullet_range


class TestGetPrompt:
    def test_article_mode(self):
        system, user = get_prompt("article", "transcript text", "Title", "Channel")
        assert system == SYSTEM_PROMPT
        assert "Title" in user
        assert "Channel" in user
        assert "transcript text" in user

    def test_tldr_mode(self):
        system, user = get_prompt("tldr", "transcript text", "Title", "Channel")
        assert "bullet" in user
        assert "3-5" in user  # short transcript

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
        long_transcript = "x " * 50000
        _, user = get_prompt("article", long_transcript, "T", "C")
        # Should be truncated to 50000 chars
        assert len(user) < 70000


class TestLengthScaling:
    def test_short_article(self):
        instructions = _length_instructions(1000, "article")
        assert "500-800" in instructions

    def test_medium_article(self):
        instructions = _length_instructions(5000, "article")
        assert "1,000-2,000" in instructions

    def test_long_article(self):
        instructions = _length_instructions(15000, "article")
        assert "2,500-4,000" in instructions

    def test_very_long_article(self):
        instructions = _length_instructions(40000, "article")
        assert "4,000-6,000" in instructions

    def test_short_takeaways(self):
        instructions = _length_instructions(1000, "takeaways")
        assert "5-10" in instructions

    def test_long_takeaways(self):
        instructions = _length_instructions(15000, "takeaways")
        assert "20-30" in instructions

    def test_very_long_takeaways(self):
        instructions = _length_instructions(40000, "takeaways")
        assert "30-40" in instructions

    def test_no_instructions_for_unknown_mode(self):
        instructions = _length_instructions(5000, "transcript")
        assert instructions == ""


class TestBulletRange:
    def test_short_video(self):
        assert _bullet_range(1000) == "3-5"

    def test_medium_video(self):
        assert _bullet_range(5000) == "5-8"

    def test_long_video(self):
        assert _bullet_range(15000) == "8-12"

    def test_very_long_video(self):
        assert _bullet_range(40000) == "12-15"


class TestLengthInPrompts:
    def test_article_includes_length(self):
        # ~5000 words
        transcript = "word " * 5000
        _, user = get_prompt("article", transcript, "Title", "Channel")
        assert "1,000-2,000" in user

    def test_long_article_includes_length(self):
        # ~16000 words (like the Ezra Klein video)
        transcript = "word " * 16000
        _, user = get_prompt("article", transcript, "Title", "Channel")
        assert "2,500-4,000" in user

    def test_tldr_scales_bullets(self):
        # Short
        _, user = get_prompt("tldr", "short text", "Title", "Channel")
        assert "3-5" in user

        # Long (~16000 words)
        long_transcript = "word " * 16000
        _, user = get_prompt("tldr", long_transcript, "Title", "Channel")
        assert "8-12" in user

    def test_takeaways_scales(self):
        long_transcript = "word " * 16000
        _, user = get_prompt("takeaways", long_transcript, "Title", "Channel")
        assert "20-30" in user

    def test_chaptered_article_includes_length(self):
        transcript = "word " * 16000
        _, user = get_prompt(
            "article", transcript, "Title", "Channel",
            has_chapter_structure=True,
        )
        assert "2,500-4,000" in user
