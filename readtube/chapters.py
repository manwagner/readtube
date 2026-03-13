"""Chapter-aware transcript processing."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class Chapter:
    title: str
    start_time: float
    end_time: float
    transcript: str = ""
    word_count: int = 0


@dataclass
class ChapteredTranscript:
    chapters: List[Chapter] = field(default_factory=list)
    total_word_count: int = 0
    has_chapters: bool = False


def format_timestamp(seconds: float) -> str:
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    if hours > 0:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"


def timestamp_to_seconds(timestamp: str) -> float:
    parts = timestamp.strip().split(":")
    try:
        if len(parts) == 3:
            return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
        elif len(parts) == 2:
            return int(parts[0]) * 60 + float(parts[1])
        else:
            return float(parts[0])
    except (ValueError, IndexError):
        return 0.0


def extract_timestamps_from_transcript(transcript: str) -> List[Tuple[float, str]]:
    pattern = r"\[?(\d{1,2}:\d{2}(?::\d{2})?)\]?\s*(.+?)(?=\[?\d{1,2}:\d{2}|$)"
    matches = re.findall(pattern, transcript, re.DOTALL)
    results = []
    for timestamp_str, text in matches:
        seconds = timestamp_to_seconds(timestamp_str)
        text = text.strip()
        if text:
            results.append((seconds, text))
    return results


def split_transcript_by_chapters(
    transcript: str,
    chapters: List[Dict[str, Any]],
    timestamped: bool = False,
) -> ChapteredTranscript:
    result = ChapteredTranscript()

    if not chapters:
        result.has_chapters = False
        result.chapters = [
            Chapter(
                title="Full Video",
                start_time=0,
                end_time=0,
                transcript=transcript,
                word_count=len(transcript.split()),
            )
        ]
        result.total_word_count = result.chapters[0].word_count
        return result

    result.has_chapters = True
    sorted_chapters = sorted(chapters, key=lambda c: c.get("start_time", 0))

    if timestamped:
        segments = extract_timestamps_from_transcript(transcript)
        for i, ch_data in enumerate(sorted_chapters):
            start = ch_data.get("start_time", 0)
            end = ch_data.get("end_time", 0)
            if not end and i < len(sorted_chapters) - 1:
                end = sorted_chapters[i + 1].get("start_time", float("inf"))
            elif not end:
                end = float("inf")

            chapter_text = []
            for seg_time, seg_text in segments:
                if start <= seg_time < end:
                    chapter_text.append(seg_text)

            chapter = Chapter(
                title=ch_data.get("title", f"Chapter {i + 1}"),
                start_time=start,
                end_time=end if end != float("inf") else 0,
                transcript=" ".join(chapter_text),
            )
            chapter.word_count = len(chapter.transcript.split())
            result.chapters.append(chapter)
    else:
        words = transcript.split()
        total_words = len(words)
        total_duration = max(c.get("end_time", 0) for c in sorted_chapters) if sorted_chapters else 1

        word_index = 0
        for i, ch_data in enumerate(sorted_chapters):
            start = ch_data.get("start_time", 0)
            end = ch_data.get("end_time", 0)
            if not end and i < len(sorted_chapters) - 1:
                end = sorted_chapters[i + 1].get("start_time", total_duration)
            elif not end:
                end = total_duration

            duration = end - start
            proportion = duration / total_duration if total_duration > 0 else (1.0 / len(sorted_chapters))
            chapter_word_count = int(total_words * proportion)
            end_index = min(word_index + chapter_word_count, total_words)

            chapter = Chapter(
                title=ch_data.get("title", f"Chapter {i + 1}"),
                start_time=start,
                end_time=end,
                transcript=" ".join(words[word_index:end_index]),
                word_count=end_index - word_index,
            )
            result.chapters.append(chapter)
            word_index = end_index

        if word_index < total_words and result.chapters:
            result.chapters[-1].transcript += " " + " ".join(words[word_index:])
            result.chapters[-1].word_count = len(result.chapters[-1].transcript.split())

    result.total_word_count = sum(c.word_count for c in result.chapters)
    return result


def format_chapters_for_prompt(chapters: List[Dict[str, Any]]) -> str:
    if not chapters:
        return ""
    lines = []
    for ch in chapters:
        timestamp = format_timestamp(ch.get("start_time", 0))
        title = ch.get("title", "Untitled")
        lines.append(f"- [{timestamp}] {title}")
    return "\n".join(lines)


def format_chaptered_transcript(chaptered: ChapteredTranscript) -> str:
    """Format a chaptered transcript with ## headings for LLM input."""
    if not chaptered.has_chapters:
        return chaptered.chapters[0].transcript if chaptered.chapters else ""
    parts = []
    for chapter in chaptered.chapters:
        ts = format_timestamp(chapter.start_time)
        parts.append(f"## {chapter.title} [{ts}]\n\n{chapter.transcript}")
    return "\n\n".join(parts)


def estimate_reading_time(word_count: int, wpm: int = 200) -> str:
    minutes = word_count / wpm
    if minutes < 1:
        return "less than 1 min read"
    elif minutes < 60:
        return f"{int(minutes)} min read"
    else:
        hours = int(minutes / 60)
        remaining = int(minutes % 60)
        if remaining:
            return f"{hours}h {remaining}m read"
        return f"{hours}h read"
