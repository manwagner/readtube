"""Tests for cache module."""

import tempfile
from pathlib import Path

from readtube.cache import Cache


class TestCache:
    def setup_method(self):
        self.tmpdir = tempfile.mkdtemp()
        self.cache = Cache(self.tmpdir, ttl_days=1)

    def test_set_and_get_transcript(self):
        self.cache.set_transcript("abc123", "hello world")
        result = self.cache.get_transcript("abc123")
        assert result == "hello world"

    def test_get_missing_transcript(self):
        result = self.cache.get_transcript("nonexistent")
        assert result is None

    def test_language_keying(self):
        self.cache.set_transcript("abc", "english", lang="en")
        self.cache.set_transcript("abc", "spanish", lang="es")

        assert self.cache.get_transcript("abc", lang="en") == "english"
        assert self.cache.get_transcript("abc", lang="es") == "spanish"
        assert self.cache.get_transcript("abc") is None  # no lang = different key

    def test_set_and_get_metadata(self):
        meta = {"title": "Test", "channel": "CH"}
        self.cache.set_metadata("abc", meta)
        result = self.cache.get_metadata("abc")
        assert result == meta

    def test_clear(self):
        self.cache.set_transcript("a", "text")
        self.cache.set_metadata("b", {"x": 1})
        count = self.cache.clear()
        assert count == 2
        assert self.cache.get_transcript("a") is None
        assert self.cache.get_metadata("b") is None

    def test_stats(self):
        self.cache.set_transcript("a", "hello")
        self.cache.set_metadata("b", {"x": 1})
        stats = self.cache.stats()
        assert stats["total_entries"] == 2
        assert "transcripts" in stats["by_type"]
        assert "metadata" in stats["by_type"]
        assert stats["by_type"]["transcripts"]["count"] == 1

    def test_ttl_expiration(self):
        # Create cache with 0 day TTL
        cache = Cache(self.tmpdir + "/expired", ttl_days=0)
        cache.set_transcript("abc", "text")
        # TTL is 0 days = 0 seconds, so it's already expired
        result = cache.get_transcript("abc")
        assert result is None

    def test_creates_directories(self):
        path = Path(self.tmpdir) / "nested" / "deep"
        cache = Cache(str(path))
        cache.set_transcript("abc", "hello")
        assert (path / "transcripts").exists()
