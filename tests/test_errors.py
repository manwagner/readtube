"""Tests for errors module."""

import pytest
from readtube.errors import (
    ReadtubeError,
    VideoNotFoundError,
    TranscriptNotAvailableError,
    RateLimitError,
    NetworkError,
    LLMError,
    OutputFormatError,
    EXIT_SUCCESS,
    EXIT_VIDEO_NOT_FOUND,
    EXIT_TRANSCRIPT_UNAVAILABLE,
    EXIT_LLM_ERROR,
    EXIT_OUTPUT_FORMAT_ERROR,
    is_rate_limit_error,
    is_retryable_error,
    calculate_delay,
    RetryConfig,
    retry_with_backoff,
    format_error_for_user,
)


class TestExitCodes:
    def test_video_not_found_exit_code(self):
        assert VideoNotFoundError("abc").exit_code == EXIT_VIDEO_NOT_FOUND

    def test_transcript_unavailable_exit_code(self):
        assert TranscriptNotAvailableError("abc").exit_code == EXIT_TRANSCRIPT_UNAVAILABLE

    def test_llm_error_exit_code(self):
        assert LLMError("ollama", "fail").exit_code == EXIT_LLM_ERROR

    def test_output_format_error_exit_code(self):
        assert OutputFormatError("pdf", "missing").exit_code == EXIT_OUTPUT_FORMAT_ERROR


class TestFriendlyMessages:
    def test_base_error(self):
        e = ReadtubeError("something broke", "try this")
        assert "error: something broke" in e.friendly_message
        assert "try this" in e.friendly_message

    def test_video_not_found(self):
        e = VideoNotFoundError("abc123")
        assert "not found" in e.friendly_message

    def test_transcript_with_languages(self):
        e = TranscriptNotAvailableError("abc", ["en", "es", "de"])
        assert "en, es, de" in e.friendly_message
        assert "--lang" in e.friendly_message

    def test_llm_error_hints(self):
        e = LLMError("ollama", "connection refused")
        assert "ollama serve" in e.friendly_message

        e = LLMError("claude", "unauthorized")
        assert "ANTHROPIC_API_KEY" in e.friendly_message

    def test_output_format_hints(self):
        e = OutputFormatError("epub", "missing ebooklib")
        assert "readtube[epub]" in e.friendly_message

        e = OutputFormatError("pdf", "missing weasyprint")
        assert "readtube[pdf]" in e.friendly_message


class TestRateLimitDetection:
    def test_detects_rate_limit(self):
        assert is_rate_limit_error(Exception("429 Too Many Requests"))
        assert is_rate_limit_error(Exception("rate limit exceeded"))
        assert is_rate_limit_error(Exception("IP blocked"))

    def test_non_rate_limit(self):
        assert not is_rate_limit_error(Exception("file not found"))
        assert not is_rate_limit_error(Exception("syntax error"))


class TestRetryable:
    def test_rate_limit_is_retryable(self):
        assert is_retryable_error(Exception("429 rate limit"))

    def test_network_errors_retryable(self):
        assert is_retryable_error(Exception("connection timeout"))
        assert is_retryable_error(Exception("503 service unavailable"))

    def test_non_retryable(self):
        assert not is_retryable_error(Exception("invalid argument"))


class TestRetryWithBackoff:
    def test_succeeds_first_try(self):
        result = retry_with_backoff(lambda: 42)
        assert result == 42

    def test_retries_on_retryable_error(self):
        attempts = [0]

        def flaky():
            attempts[0] += 1
            if attempts[0] < 2:
                raise Exception("503 unavailable")
            return "ok"

        config = RetryConfig(max_attempts=3, base_delay=0.01, jitter=False)
        result = retry_with_backoff(flaky, config=config)
        assert result == "ok"
        assert attempts[0] == 2

    def test_raises_non_retryable_immediately(self):
        def fail():
            raise ValueError("bad input")

        with pytest.raises(ValueError):
            retry_with_backoff(fail, config=RetryConfig(max_attempts=3))

    def test_exhausts_retries(self):
        def always_fail():
            raise Exception("503 unavailable")

        config = RetryConfig(max_attempts=2, base_delay=0.01, jitter=False)
        with pytest.raises(Exception, match="503"):
            retry_with_backoff(always_fail, config=config)


class TestCalculateDelay:
    def test_exponential_growth(self):
        config = RetryConfig(base_delay=1.0, exponential_base=2.0, jitter=False)
        assert calculate_delay(0, config) == 1.0
        assert calculate_delay(1, config) == 2.0
        assert calculate_delay(2, config) == 4.0

    def test_max_delay_cap(self):
        config = RetryConfig(base_delay=1.0, max_delay=5.0, exponential_base=2.0, jitter=False)
        assert calculate_delay(10, config) == 5.0


class TestFormatErrorForUser:
    def test_readtube_error(self):
        e = VideoNotFoundError("abc")
        msg = format_error_for_user(e)
        assert "not found" in msg

    def test_generic_rate_limit(self):
        msg = format_error_for_user(Exception("429 too many requests"))
        assert "blocking" in msg

    def test_generic_error(self):
        msg = format_error_for_user(Exception("something went wrong"))
        assert "something went wrong" in msg
