"""Tests for chapters module."""

from readtube.chapters import (
    format_timestamp,
    timestamp_to_seconds,
    split_transcript_by_chapters,
    format_chapters_for_prompt,
    format_chaptered_transcript,
    estimate_reading_time,
)


class TestFormatTimestamp:
    def test_minutes_seconds(self):
        assert format_timestamp(0) == "0:00"
        assert format_timestamp(65) == "1:05"
        assert format_timestamp(599) == "9:59"

    def test_hours(self):
        assert format_timestamp(3600) == "1:00:00"
        assert format_timestamp(3661) == "1:01:01"


class TestTimestampToSeconds:
    def test_mm_ss(self):
        assert timestamp_to_seconds("1:05") == 65.0
        assert timestamp_to_seconds("0:00") == 0.0

    def test_hh_mm_ss(self):
        assert timestamp_to_seconds("1:01:01") == 3661.0

    def test_invalid(self):
        assert timestamp_to_seconds("invalid") == 0.0


class TestSplitByChapters:
    def test_no_chapters(self):
        result = split_transcript_by_chapters("hello world", [])
        assert not result.has_chapters
        assert len(result.chapters) == 1
        assert result.chapters[0].transcript == "hello world"

    def test_proportional_split(self):
        chapters = [
            {"title": "Intro", "start_time": 0, "end_time": 100},
            {"title": "Main", "start_time": 100, "end_time": 300},
            {"title": "End", "start_time": 300, "end_time": 400},
        ]
        words = " ".join(["word"] * 100)
        result = split_transcript_by_chapters(words, chapters)

        assert result.has_chapters
        assert len(result.chapters) == 3
        assert result.chapters[0].title == "Intro"
        assert result.chapters[1].title == "Main"
        # Main is 200/400 = 50% of duration, should get ~50 words
        assert result.chapters[1].word_count >= 40

    def test_total_word_count(self):
        chapters = [
            {"title": "A", "start_time": 0, "end_time": 50},
            {"title": "B", "start_time": 50, "end_time": 100},
        ]
        words = " ".join(["word"] * 50)
        result = split_transcript_by_chapters(words, chapters)
        assert result.total_word_count == 50


class TestFormatChaptersForPrompt:
    def test_empty(self):
        assert format_chapters_for_prompt([]) == ""

    def test_formats_correctly(self):
        chapters = [
            {"title": "Intro", "start_time": 0},
            {"title": "Main", "start_time": 120},
        ]
        text = format_chapters_for_prompt(chapters)
        assert "[0:00] Intro" in text
        assert "[2:00] Main" in text


class TestFormatChapteredTranscript:
    def test_with_chapters(self):
        chapters = [
            {"title": "Start", "start_time": 0, "end_time": 60},
            {"title": "End", "start_time": 60, "end_time": 120},
        ]
        result = split_transcript_by_chapters("hello world foo bar", chapters)
        text = format_chaptered_transcript(result)
        assert "## Start [0:00]" in text
        assert "## End [1:00]" in text


class TestEstimateReadingTime:
    def test_short(self):
        assert "less than 1 min" in estimate_reading_time(50)

    def test_minutes(self):
        assert "5 min" in estimate_reading_time(1000)

    def test_hours(self):
        assert "1h" in estimate_reading_time(15000)
