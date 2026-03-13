"""Custom exceptions and error handling for Readtube."""

from __future__ import annotations

import functools
import random
import sys
import time
from typing import Any, Callable, Optional, TypeVar

T = TypeVar("T")

# Exit codes per DESIGN.md
EXIT_SUCCESS = 0
EXIT_GENERAL = 1
EXIT_INVALID_ARGS = 2
EXIT_VIDEO_NOT_FOUND = 3
EXIT_TRANSCRIPT_UNAVAILABLE = 4
EXIT_LLM_ERROR = 5
EXIT_OUTPUT_FORMAT_ERROR = 6


class ReadtubeError(Exception):
    """Base exception for all Readtube errors."""

    exit_code = EXIT_GENERAL

    def __init__(self, message: str, hint: Optional[str] = None):
        self.message = message
        self.hint = hint
        super().__init__(self.friendly_message)

    @property
    def friendly_message(self) -> str:
        msg = f"error: {self.message}"
        if self.hint:
            msg += f"\n  → {self.hint}"
        return msg


class VideoNotFoundError(ReadtubeError):
    exit_code = EXIT_VIDEO_NOT_FOUND

    def __init__(self, video_id: str, reason: Optional[str] = None):
        message = f"video not found or is private"
        if reason:
            message = f"video '{video_id}': {reason}"
        super().__init__(message, "check that the URL is correct and the video is publicly available")


class TranscriptNotAvailableError(ReadtubeError):
    exit_code = EXIT_TRANSCRIPT_UNAVAILABLE

    def __init__(self, video_id: str, available_languages: Optional[list] = None):
        message = f"no transcript available for video '{video_id}'"
        hint = "this video may not have captions enabled"
        if available_languages:
            hint = f"available languages: {', '.join(available_languages)}\n  → try: readtube URL --lang <code>"
        super().__init__(message, hint)


class RateLimitError(ReadtubeError):
    exit_code = EXIT_GENERAL

    def __init__(self, retry_after: Optional[int] = None):
        message = "YouTube is temporarily blocking requests"
        hint = "wait a few minutes and try again, or use a different network"
        if retry_after:
            hint = f"retry after {retry_after} seconds"
        super().__init__(message, hint)


class NetworkError(ReadtubeError):
    exit_code = EXIT_GENERAL

    def __init__(self, message: str):
        super().__init__(message, "check your internet connection")


class LLMError(ReadtubeError):
    exit_code = EXIT_LLM_ERROR

    def __init__(self, backend: str, message: str):
        hints = {
            "ollama": "is Ollama running? try: ollama serve",
            "claude": "set ANTHROPIC_API_KEY or run: readtube config --init",
            "openai": "set OPENAI_API_KEY or run: readtube config --init",
        }
        hint = hints.get(backend, f"run: readtube config --init")
        super().__init__(f"LLM error ({backend}): {message}", hint)


class OutputFormatError(ReadtubeError):
    exit_code = EXIT_OUTPUT_FORMAT_ERROR

    def __init__(self, fmt: str, message: str):
        hints = {
            "epub": "install with: pip install readtube[epub]",
            "pdf": "install with: pip install readtube[pdf]",
            "html": "install with: pip install readtube[html]",
        }
        hint = hints.get(fmt, f"check that {fmt} generation is configured")
        super().__init__(f"failed to generate {fmt}: {message}", hint)


class RetryConfig:
    def __init__(
        self,
        max_attempts: int = 3,
        base_delay: float = 1.0,
        max_delay: float = 60.0,
        exponential_base: float = 2.0,
        jitter: bool = True,
    ):
        self.max_attempts = max_attempts
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.exponential_base = exponential_base
        self.jitter = jitter


YOUTUBE_RETRY_CONFIG = RetryConfig(max_attempts=5, base_delay=2.0, max_delay=120.0)
LLM_RETRY_CONFIG = RetryConfig(max_attempts=3, base_delay=1.0, max_delay=30.0)
NETWORK_RETRY_CONFIG = RetryConfig(max_attempts=3, base_delay=0.5, max_delay=10.0)


def calculate_delay(attempt: int, config: RetryConfig) -> float:
    delay = config.base_delay * (config.exponential_base ** attempt)
    delay = min(delay, config.max_delay)
    if config.jitter:
        jitter_range = delay * 0.25
        delay += random.uniform(-jitter_range, jitter_range)
    return max(0, delay)


def is_rate_limit_error(error: Exception) -> bool:
    error_str = str(error).lower()
    indicators = ["rate limit", "too many requests", "429", "blocking", "blocked", "quota"]
    return any(i in error_str for i in indicators)


def is_retryable_error(error: Exception) -> bool:
    if is_rate_limit_error(error):
        return True
    error_str = str(error).lower()
    network_errors = ["timeout", "connection", "network", "temporary", "unavailable", "502", "503", "504"]
    return any(err in error_str for err in network_errors)


def retry_with_backoff(
    func: Callable[[], T],
    config: Optional[RetryConfig] = None,
    on_retry: Optional[Callable[[Exception, int, float], None]] = None,
) -> T:
    if config is None:
        config = RetryConfig()

    last_exception: Optional[Exception] = None

    for attempt in range(config.max_attempts):
        try:
            return func()
        except Exception as e:
            last_exception = e
            if attempt >= config.max_attempts - 1:
                break
            if not is_retryable_error(e):
                raise
            delay = calculate_delay(attempt, config)
            if is_rate_limit_error(e):
                delay = max(delay, 30.0)
            if on_retry:
                on_retry(e, attempt + 1, delay)
            time.sleep(delay)

    if last_exception:
        raise last_exception
    raise RuntimeError("Retry loop completed without result or exception")


def format_error_for_user(error: Exception) -> str:
    if isinstance(error, ReadtubeError):
        return error.friendly_message
    error_str = str(error).lower()
    if is_rate_limit_error(error):
        return RateLimitError().friendly_message
    if "transcript" in error_str and ("not available" in error_str or "disabled" in error_str):
        return TranscriptNotAvailableError("unknown").friendly_message
    if "video" in error_str and ("unavailable" in error_str or "not found" in error_str or "private" in error_str):
        return VideoNotFoundError("unknown", str(error)).friendly_message
    if "connection" in error_str or "timeout" in error_str or "network" in error_str:
        return NetworkError(str(error)).friendly_message
    return f"error: {error}"


def die(error: Exception) -> None:
    """Print error and exit with appropriate code."""
    print(format_error_for_user(error), file=sys.stderr)
    code = error.exit_code if isinstance(error, ReadtubeError) else EXIT_GENERAL
    sys.exit(code)
