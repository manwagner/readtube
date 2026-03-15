"""Genre detection and genre-specific prompt templates for video transcripts."""

import re

GENRES = ["interview", "tutorial", "lecture", "documentary", "debate", "conference"]

_GENRE_SYSTEM_PROMPTS = {
    "interview": (
        "You transform interview/podcast transcripts into well-structured articles. "
        "Preserve speaker voices, attribute quotes, maintain Q&A flow where natural. "
        "Use '**Speaker Name:**' for attribution when speakers are identifiable."
    ),
    "tutorial": (
        "You transform tutorial transcripts into step-by-step guides. "
        "Use numbered steps, code blocks where appropriate, list prerequisites. "
        "Focus on actionable instructions."
    ),
    "lecture": (
        "You transform lecture transcripts into educational articles. "
        "Build a clear concept hierarchy, define key terms, show logical progression of ideas."
    ),
    "documentary": (
        "You transform documentary/journalism transcripts into narrative articles. "
        "Maintain chronological flow, provide context, preserve the storytelling arc."
    ),
    "debate": (
        "You transform debate/panel transcripts into balanced analysis. "
        "Present multiple viewpoints clearly, note areas of agreement and disagreement, "
        "attribute positions to speakers."
    ),
    "conference": (
        "You transform conference talk transcripts into technical articles. "
        "Structure as problem \u2192 approach \u2192 results. Include key data points and conclusions."
    ),
}

# Ordered list of (pattern, genre) rules applied to title, then channel, then description.
# Title rules take priority over channel rules, which take priority over description rules.
_TITLE_RULES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"interview", re.IGNORECASE), "interview"),
    (re.compile(r"podcast", re.IGNORECASE), "interview"),
    (re.compile(r"tutorial", re.IGNORECASE), "tutorial"),
    (re.compile(r"how\s+to", re.IGNORECASE), "tutorial"),
    (re.compile(r"step\s+by\s+step", re.IGNORECASE), "tutorial"),
    (re.compile(r"lecture", re.IGNORECASE), "lecture"),
    (re.compile(r"course", re.IGNORECASE), "lecture"),
    (re.compile(r"documentary", re.IGNORECASE), "documentary"),
    (re.compile(r"investigat", re.IGNORECASE), "documentary"),
    (re.compile(r"deep\s+dive", re.IGNORECASE), "documentary"),
    (re.compile(r"debate", re.IGNORECASE), "debate"),
    (re.compile(r"panel", re.IGNORECASE), "debate"),
    (re.compile(r"discussion", re.IGNORECASE), "debate"),
    (re.compile(r"keynote", re.IGNORECASE), "conference"),
    (re.compile(r"conference", re.IGNORECASE), "conference"),
    (re.compile(r"\btalk\b", re.IGNORECASE), "conference"),
]

_CHANNEL_RULES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"podcast", re.IGNORECASE), "interview"),
    (re.compile(r"academy", re.IGNORECASE), "lecture"),
    (re.compile(r"university", re.IGNORECASE), "lecture"),
]

_DESCRIPTION_RULES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"in\s+this\s+episode", re.IGNORECASE), "interview"),
    (re.compile(r"my\s+guest", re.IGNORECASE), "interview"),
    (re.compile(r"in\s+this\s+tutorial", re.IGNORECASE), "tutorial"),
]

_DEFAULT_GENRE = "lecture"


def detect_genre(title: str, channel: str, description: str = "") -> str:
    """Detect the genre of a video from its metadata.

    Checks title keywords first, then channel name patterns, then description
    patterns. Returns the default genre ("lecture") if nothing matches.
    """
    for pattern, genre in _TITLE_RULES:
        if pattern.search(title):
            return genre

    for pattern, genre in _CHANNEL_RULES:
        if pattern.search(channel):
            return genre

    for pattern, genre in _DESCRIPTION_RULES:
        if pattern.search(description):
            return genre

    return _DEFAULT_GENRE


def get_genre_system_prompt(genre: str) -> str:
    """Return the system prompt tailored to the given genre.

    Raises ``KeyError`` if the genre is not recognised.
    """
    return _GENRE_SYSTEM_PROMPTS[genre]


def list_genres() -> list[str]:
    """Return the list of supported genres."""
    return list(GENRES)
