"""Tests for the SponsorBlock integration module."""

import json
import urllib.error
from unittest.mock import patch, MagicMock

from readtube.sponsorblock import (
    get_sponsor_segments,
    filter_transcript,
    remove_sponsors,
)


# -- Fixtures ----------------------------------------------------------------

SAMPLE_API_RESPONSE = [
    {
        "segment": [30.0, 60.0],
        "category": "sponsor",
        "UUID": "abc123",
    },
    {
        "segment": [120.0, 150.0],
        "category": "selfpromo",
        "UUID": "def456",
    },
]

TIMED_SEGMENTS = [
    {"text": "Hello everyone", "start": 0.0, "duration": 5.0},
    {"text": "welcome to the video", "start": 5.0, "duration": 5.0},
    {"text": "let me tell you about our sponsor", "start": 30.0, "duration": 10.0},
    {"text": "use code SAVE20", "start": 40.0, "duration": 10.0},
    {"text": "okay back to the topic", "start": 60.0, "duration": 5.0},
    {"text": "here is the main content", "start": 65.0, "duration": 10.0},
    {"text": "check out my merch", "start": 120.0, "duration": 10.0},
    {"text": "link in description", "start": 130.0, "duration": 10.0},
    {"text": "thanks for watching", "start": 150.0, "duration": 5.0},
]


def _make_http_response(data: list, status: int = 200) -> MagicMock:
    """Create a mock HTTP response."""
    body = json.dumps(data).encode()
    resp = MagicMock()
    resp.read.return_value = body
    resp.status = status
    resp.__enter__ = MagicMock(return_value=resp)
    resp.__exit__ = MagicMock(return_value=False)
    return resp


# -- get_sponsor_segments tests ----------------------------------------------


class TestGetSponsorSegments:
    @patch("readtube.sponsorblock.urllib.request.urlopen")
    def test_parse_api_response(self, mock_urlopen):
        mock_urlopen.return_value = _make_http_response(SAMPLE_API_RESPONSE)

        segments = get_sponsor_segments("testvideo123")

        assert len(segments) == 2
        assert segments[0] == {"start": 30.0, "end": 60.0, "category": "sponsor"}
        assert segments[1] == {"start": 120.0, "end": 150.0, "category": "selfpromo"}

    @patch("readtube.sponsorblock.urllib.request.urlopen")
    def test_graceful_fallback_on_network_error(self, mock_urlopen):
        mock_urlopen.side_effect = urllib.error.URLError("connection refused")

        result = get_sponsor_segments("testvideo123")

        assert result == []

    @patch("readtube.sponsorblock.urllib.request.urlopen")
    def test_graceful_fallback_on_404(self, mock_urlopen):
        mock_urlopen.side_effect = urllib.error.HTTPError(
            url="https://sponsor.ajay.app/api/skipSegments",
            code=404,
            msg="Not Found",
            hdrs=None,
            fp=None,
        )

        result = get_sponsor_segments("nonexistent_video")

        assert result == []

    @patch("readtube.sponsorblock.urllib.request.urlopen")
    def test_graceful_fallback_on_timeout(self, mock_urlopen):
        mock_urlopen.side_effect = TimeoutError("timed out")

        result = get_sponsor_segments("testvideo123", timeout=0.1)

        assert result == []

    @patch("readtube.sponsorblock.urllib.request.urlopen")
    def test_empty_response(self, mock_urlopen):
        mock_urlopen.return_value = _make_http_response([])

        result = get_sponsor_segments("testvideo123")

        assert result == []

    @patch("readtube.sponsorblock.urllib.request.urlopen")
    def test_malformed_json(self, mock_urlopen):
        resp = MagicMock()
        resp.read.return_value = b"not json"
        resp.__enter__ = MagicMock(return_value=resp)
        resp.__exit__ = MagicMock(return_value=False)
        mock_urlopen.return_value = resp

        result = get_sponsor_segments("testvideo123")

        assert result == []


# -- filter_transcript tests -------------------------------------------------


class TestFilterTranscript:
    def test_no_sponsor_segments_returns_unchanged(self):
        transcript = "Hello everyone welcome to the video"
        result = filter_transcript(transcript, [], TIMED_SEGMENTS)

        assert result == transcript

    def test_no_timed_segments_returns_unchanged(self):
        transcript = "Hello everyone welcome to the video"
        segments = [{"start": 0.0, "end": 10.0, "category": "sponsor"}]

        result = filter_transcript(transcript, segments, None)

        assert result == transcript

    def test_filter_single_sponsor_segment(self):
        sponsor = [{"start": 30.0, "end": 60.0, "category": "sponsor"}]

        result = filter_transcript("ignored", sponsor, TIMED_SEGMENTS)

        assert "let me tell you about our sponsor" not in result
        assert "use code SAVE20" not in result
        assert "Hello everyone" in result
        assert "okay back to the topic" in result

    def test_filter_multiple_sponsor_segments(self):
        sponsors = [
            {"start": 30.0, "end": 60.0, "category": "sponsor"},
            {"start": 120.0, "end": 150.0, "category": "selfpromo"},
        ]

        result = filter_transcript("ignored", sponsors, TIMED_SEGMENTS)

        # Sponsored content removed
        assert "let me tell you about our sponsor" not in result
        assert "use code SAVE20" not in result
        assert "check out my merch" not in result
        assert "link in description" not in result
        # Non-sponsored content kept
        assert "Hello everyone" in result
        assert "welcome to the video" in result
        assert "okay back to the topic" in result
        assert "here is the main content" in result
        assert "thanks for watching" in result

    def test_segment_at_sponsor_boundary_excluded(self):
        """A timed segment whose start equals the sponsor start is excluded."""
        sponsor = [{"start": 5.0, "end": 10.0, "category": "sponsor"}]
        timed = [
            {"text": "before", "start": 0.0, "duration": 5.0},
            {"text": "at boundary", "start": 5.0, "duration": 5.0},
            {"text": "after", "start": 10.0, "duration": 5.0},
        ]

        result = filter_transcript("ignored", sponsor, timed)

        assert "before" in result
        assert "at boundary" not in result
        assert "after" in result

    def test_segment_at_sponsor_end_not_excluded(self):
        """A timed segment whose start equals the sponsor end is NOT excluded (half-open interval)."""
        sponsor = [{"start": 5.0, "end": 10.0, "category": "sponsor"}]
        timed = [
            {"text": "before", "start": 0.0, "duration": 5.0},
            {"text": "during", "start": 7.0, "duration": 3.0},
            {"text": "at end", "start": 10.0, "duration": 5.0},
        ]

        result = filter_transcript("ignored", sponsor, timed)

        assert "before" in result
        assert "during" not in result
        assert "at end" in result

    def test_all_segments_sponsored(self):
        """When everything is sponsored, result is empty."""
        sponsor = [{"start": 0.0, "end": 200.0, "category": "sponsor"}]

        result = filter_transcript("ignored", sponsor, TIMED_SEGMENTS)

        assert result == ""


# -- remove_sponsors tests ---------------------------------------------------


class TestRemoveSponsors:
    @patch("readtube.sponsorblock.urllib.request.urlopen")
    def test_combines_fetch_and_filter(self, mock_urlopen):
        mock_urlopen.return_value = _make_http_response(SAMPLE_API_RESPONSE)

        result = remove_sponsors("testvideo123", "ignored", TIMED_SEGMENTS)

        assert "let me tell you about our sponsor" not in result
        assert "Hello everyone" in result
        assert "okay back to the topic" in result

    @patch("readtube.sponsorblock.urllib.request.urlopen")
    def test_returns_original_on_api_failure(self, mock_urlopen):
        mock_urlopen.side_effect = urllib.error.URLError("fail")
        transcript = "Hello everyone welcome to the video"

        result = remove_sponsors("testvideo123", transcript, TIMED_SEGMENTS)

        assert result == transcript

    @patch("readtube.sponsorblock.urllib.request.urlopen")
    def test_returns_original_without_timed_segments(self, mock_urlopen):
        mock_urlopen.return_value = _make_http_response(SAMPLE_API_RESPONSE)
        transcript = "Hello everyone welcome to the video"

        result = remove_sponsors("testvideo123", transcript, None)

        assert result == transcript
