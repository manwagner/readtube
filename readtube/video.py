"""Video metadata fetching via yt-dlp."""

from __future__ import annotations

from typing import Any, Dict, List, Optional, TypedDict

import yt_dlp

from .errors import (
    NetworkError,
    RateLimitError,
    VideoNotFoundError,
    is_rate_limit_error,
)

MIN_DURATION_SECONDS = 60


class ChapterInfo(TypedDict):
    title: str
    start_time: float
    end_time: float


class VideoInfo(TypedDict, total=False):
    title: str
    video_id: str
    description: str
    channel: str
    url: str
    thumbnail: Optional[str]
    duration: int
    chapters: List[ChapterInfo]


def is_playlist_url(url: str) -> bool:
    return "playlist?list=" in url or "&list=" in url


def _extract_chapters(raw_chapters: list) -> List[ChapterInfo]:
    chapters = []
    for ch in raw_chapters or []:
        chapters.append({
            "title": ch.get("title", ""),
            "start_time": ch.get("start_time", 0),
            "end_time": ch.get("end_time", 0),
        })
    return chapters


def _best_thumbnail(entry: dict) -> Optional[str]:
    thumb = entry.get("thumbnail")
    if not thumb:
        thumbnails = entry.get("thumbnails", [])
        if thumbnails:
            thumb = thumbnails[-1].get("url")
    return thumb


def _entry_to_video_info(entry: dict) -> VideoInfo:
    video_id = entry.get("id")
    return {
        "title": entry.get("title", "Unknown Title"),
        "video_id": video_id,
        "description": entry.get("description", ""),
        "channel": entry.get("channel", entry.get("uploader", "Unknown")),
        "url": f"https://www.youtube.com/watch?v={video_id}",
        "thumbnail": _best_thumbnail(entry),
        "duration": entry.get("duration", 0),
        "chapters": _extract_chapters(entry.get("chapters")),
    }


def get_video_info(video_url: str) -> VideoInfo:
    """Fetch metadata for a single video. Raises on failure."""
    ydl_opts = {"quiet": True, "no_warnings": True}

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            result = ydl.extract_info(video_url, download=False)
            if not result:
                raise VideoNotFoundError(video_url)
            return _entry_to_video_info(result)
    except (VideoNotFoundError, RateLimitError, NetworkError):
        raise
    except Exception as e:
        error_str = str(e).lower()
        if is_rate_limit_error(e):
            raise RateLimitError()
        if "not available" in error_str or "private" in error_str or "unavailable" in error_str:
            raise VideoNotFoundError(video_url, str(e))
        if "connection" in error_str or "timeout" in error_str or "network" in error_str:
            raise NetworkError(str(e))
        raise VideoNotFoundError(video_url, str(e))


def get_playlist_videos(
    playlist_url: str,
    max_videos: Optional[int] = None,
) -> List[VideoInfo]:
    """Fetch all videos from a playlist."""
    ydl_opts = {"quiet": True, "no_warnings": True, "extract_flat": False}
    if max_videos:
        ydl_opts["playlistend"] = max_videos

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            result = ydl.extract_info(playlist_url, download=False)
            if not result:
                return []

            videos = []
            for entry in result.get("entries", []):
                if entry is None:
                    continue
                duration = entry.get("duration", 0)
                if duration and duration < MIN_DURATION_SECONDS:
                    continue
                videos.append(_entry_to_video_info(entry))
            return videos

    except Exception as e:
        if is_rate_limit_error(e):
            raise RateLimitError()
        raise
