"""SponsorBlock integration for filtering sponsor segments from transcripts."""

from __future__ import annotations

import json
import urllib.request
import urllib.error
from typing import Any

API_BASE = "https://sponsor.ajay.app/api/skipSegments"
CATEGORIES = '["sponsor","selfpromo","interaction","intro","outro"]'


def get_sponsor_segments(video_id: str, timeout: float = 3.0) -> list[dict[str, Any]]:
    """Fetch sponsor segments from the SponsorBlock API.

    Returns a list of dicts with keys: start (float), end (float), category (str).
    On any error (network, timeout, 404), returns an empty list.
    """
    url = f"{API_BASE}?videoID={video_id}&categories={CATEGORIES}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "readtube"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode())
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError, json.JSONDecodeError, ValueError):
        return []

    segments = []
    for item in data:
        seg = item.get("segment")
        if seg and len(seg) == 2:
            segments.append({
                "start": float(seg[0]),
                "end": float(seg[1]),
                "category": item.get("category", "sponsor"),
            })
    return segments


def filter_transcript(
    transcript: str,
    segments: list[dict[str, Any]],
    timed_segments: list[dict[str, Any]] | None = None,
) -> str:
    """Remove transcript portions that fall within sponsor time ranges.

    Args:
        transcript: The full transcript as a plain string.
        segments: Sponsor segments from get_sponsor_segments().
        timed_segments: Timed transcript segments from get_transcript_segments(),
            each with 'text', 'start', and 'duration' keys. Required for filtering;
            if not provided, the transcript is returned unchanged.

    Returns:
        The transcript with sponsor portions removed.
    """
    if not segments or not timed_segments:
        return transcript

    kept = []
    for ts in timed_segments:
        start = float(ts.get("start", 0.0))
        if not _in_sponsor_range(start, segments):
            kept.append(ts.get("text", "").strip())

    return " ".join(t for t in kept if t)


def _in_sponsor_range(time: float, segments: list[dict[str, Any]]) -> bool:
    """Check whether a timestamp falls within any sponsor segment."""
    for seg in segments:
        if seg["start"] <= time < seg["end"]:
            return True
    return False


def remove_sponsors(
    video_id: str,
    transcript: str,
    timed_segments: list[dict[str, Any]] | None = None,
    timeout: float = 3.0,
) -> str:
    """Convenience function: fetch sponsor segments and filter the transcript.

    Combines get_sponsor_segments() and filter_transcript() into a single call.
    """
    segments = get_sponsor_segments(video_id, timeout=timeout)
    return filter_transcript(transcript, segments, timed_segments)
