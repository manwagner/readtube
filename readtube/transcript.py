"""Transcript fetching from YouTube."""

from __future__ import annotations

from typing import Any, Dict, List, Optional, TypedDict

from youtube_transcript_api import YouTubeTranscriptApi

from .errors import (
    RateLimitError,
    TranscriptNotAvailableError,
    is_rate_limit_error,
)


class TranscriptSegment(TypedDict):
    text: str
    start: float
    duration: float


def _list_transcripts(video_id: str):
    """Get transcript list, compatible across youtube-transcript-api versions."""
    try:
        api = YouTubeTranscriptApi()
        if hasattr(api, "list"):
            return api.list(video_id)
    except Exception:
        pass
    if hasattr(YouTubeTranscriptApi, "list_transcripts"):
        return YouTubeTranscriptApi.list_transcripts(video_id)
    raise RuntimeError("YouTubeTranscriptApi does not support transcript listing")


def _seg_text(segment) -> str:
    if isinstance(segment, dict):
        return str(segment.get("text", ""))
    return str(getattr(segment, "text", ""))


def _seg_start(segment) -> float:
    if isinstance(segment, dict):
        return float(segment.get("start", 0.0))
    return float(getattr(segment, "start", 0.0))


def _seg_duration(segment) -> float:
    if isinstance(segment, dict):
        return float(segment.get("duration", 0.0))
    return float(getattr(segment, "duration", 0.0))


def _format_ts(seconds: float) -> str:
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    if hours > 0:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"


def _find_transcript(transcript_list, lang: Optional[str] = None):
    """Find the best transcript from the list."""
    transcript = None

    if lang:
        try:
            transcript = transcript_list.find_transcript([lang])
        except Exception:
            try:
                for t in transcript_list:
                    if t.is_translatable:
                        transcript = t.translate(lang)
                        break
            except Exception:
                pass

    if transcript is None:
        # Prefer manual over auto-generated
        for t in transcript_list:
            if not t.is_generated:
                transcript = t
                break

    if transcript is None:
        transcript = next(iter(transcript_list))

    return transcript


def get_transcript(
    video_id: str,
    lang: Optional[str] = None,
    include_timestamps: bool = False,
) -> str:
    """Get transcript text for a video. Raises on failure."""
    try:
        transcript_list = _list_transcripts(video_id)
        transcript = _find_transcript(transcript_list, lang)
        transcript_data = transcript.fetch()

        if include_timestamps:
            lines = []
            for segment in transcript_data:
                ts = _format_ts(_seg_start(segment))
                text = _seg_text(segment).strip()
                lines.append(f"[{ts}] {text}")
            return "\n".join(lines)

        return " ".join(_seg_text(s) for s in transcript_data).strip()

    except (TranscriptNotAvailableError, RateLimitError):
        raise
    except Exception as e:
        if is_rate_limit_error(e):
            raise RateLimitError()
        error_str = str(e).lower()
        if "transcript" in error_str and ("disabled" in error_str or "not available" in error_str):
            try:
                languages = list_available_languages(video_id)
                lang_codes = [l["code"] for l in languages]
                raise TranscriptNotAvailableError(video_id, lang_codes)
            except TranscriptNotAvailableError:
                raise
            except Exception:
                raise TranscriptNotAvailableError(video_id)
        raise TranscriptNotAvailableError(video_id)


def get_transcript_segments(
    video_id: str,
    lang: Optional[str] = None,
) -> List[TranscriptSegment]:
    """Get transcript as timed segments."""
    try:
        transcript_list = _list_transcripts(video_id)
        transcript = _find_transcript(transcript_list, lang)
        transcript_data = transcript.fetch()

        return [
            {
                "text": _seg_text(s),
                "start": _seg_start(s),
                "duration": _seg_duration(s),
            }
            for s in transcript_data
        ]
    except (TranscriptNotAvailableError, RateLimitError):
        raise
    except Exception as e:
        if is_rate_limit_error(e):
            raise RateLimitError()
        raise TranscriptNotAvailableError(video_id)


def list_available_languages(video_id: str) -> List[Dict[str, Any]]:
    try:
        transcript_list = _list_transcripts(video_id)
        return [
            {
                "code": t.language_code,
                "name": t.language,
                "is_generated": t.is_generated,
            }
            for t in transcript_list
        ]
    except Exception as e:
        if is_rate_limit_error(e):
            raise RateLimitError()
        return []
