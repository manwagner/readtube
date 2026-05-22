"""Filesystem-based transcript and metadata cache."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any, Optional


class Cache:
    def __init__(self, cache_dir: str, ttl_days: int = 30):
        self.base = Path(cache_dir)
        self.transcripts_dir = self.base / "transcripts"
        self.metadata_dir = self.base / "metadata"
        self.ttl_seconds = ttl_days * 24 * 60 * 60

    def _ensure_dirs(self) -> None:
        self.transcripts_dir.mkdir(parents=True, exist_ok=True)
        self.metadata_dir.mkdir(parents=True, exist_ok=True)

    def _is_valid(self, path: Path) -> bool:
        if not path.exists():
            return False
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            cached_at = data.get("cached_at", 0)
            return (time.time() - cached_at) < self.ttl_seconds
        except Exception:
            return False

    def _read(self, path: Path) -> Optional[Any]:
        if not self._is_valid(path):
            return None
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            return data.get("value")
        except Exception:
            return None

    def _write(self, path: Path, value: Any) -> None:
        self._ensure_dirs()
        data = {"value": value, "cached_at": time.time()}
        path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")

    def get_transcript(self, video_id: str, lang: Optional[str] = None) -> Optional[str]:
        key = f"{video_id}_{lang or 'auto'}"
        return self._read(self.transcripts_dir / f"{key}.json")

    def set_transcript(self, video_id: str, transcript: str, lang: Optional[str] = None) -> None:
        key = f"{video_id}_{lang or 'auto'}"
        self._write(self.transcripts_dir / f"{key}.json", transcript)

    def get_metadata(self, video_id: str) -> Optional[dict]:
        return self._read(self.metadata_dir / f"{video_id}.json")

    def set_metadata(self, video_id: str, metadata: dict) -> None:
        self._write(self.metadata_dir / f"{video_id}.json", metadata)

    def clear(self) -> int:
        count = 0
        for d in [self.transcripts_dir, self.metadata_dir]:
            if d.exists():
                for f in d.glob("*.json"):
                    f.unlink()
                    count += 1
        return count

    def stats(self) -> dict:
        total = 0
        total_size = 0
        by_type: dict[str, dict] = {}

        for name, d in [("transcripts", self.transcripts_dir), ("metadata", self.metadata_dir)]:
            count = 0
            size = 0
            if d.exists():
                for f in d.glob("*.json"):
                    count += 1
                    size += f.stat().st_size
            total += count
            total_size += size
            by_type[name] = {"count": count, "size_kb": round(size / 1024, 1)}

        return {
            "total_entries": total,
            "total_size_kb": round(total_size / 1024, 1),
            "by_type": by_type,
            "cache_dir": str(self.base),
        }
