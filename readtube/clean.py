"""Transcript cleaning for YouTube auto-captions.

Cleans raw auto-generated caption text by removing artifacts, filler words,
stutters, and normalizing whitespace. Operates on the full transcript string.
"""

from __future__ import annotations

import re


def clean_transcript(text: str, raw: bool = False) -> str:
    """Clean a raw transcript string.

    If raw=True, return text unchanged. Otherwise apply the full cleaning
    pipeline: strip artifacts, remove filler, deduplicate stutters, and
    normalize whitespace.
    """
    if raw:
        return text

    text = strip_artifacts(text)
    text = remove_filler(text)
    text = deduplicate_stutters(text)
    text = normalize_whitespace(text)
    return text


def strip_artifacts(text: str) -> str:
    """Remove [bracketed annotations] that YouTube adds.

    Handles [music], [Music], [applause], [Applause], [laughter], [Laughter],
    and any other bracketed annotations.
    """
    return re.sub(r"\[[\w\s]+\]", "", text)


def remove_filler(text: str) -> str:
    """Remove filler words from transcript text.

    Removes standalone filler words: uh, um, you know, I mean, sort of,
    kind of, basically. Conservative with 'like' -- only removes it when
    it appears as clearly duplicated filler (e.g., "like like").
    """
    # Remove simple filler words/phrases (case-insensitive, word boundaries).
    # Order matters: match longer phrases first.
    filler_patterns = [
        r"\byou\s+know\b",
        r"\bi\s+mean\b",
        r"\bsort\s+of\b",
        r"\bkind\s+of\b",
        r"\bbasically\b",
        r"\buh\b",
        r"\bum\b",
    ]

    for pattern in filler_patterns:
        text = re.sub(pattern, "", text, flags=re.IGNORECASE)

    # Handle "like" conservatively: only remove duplicate "like like".
    text = re.sub(r"\blike(\s+like)+\b", "", text, flags=re.IGNORECASE)

    return text


def deduplicate_stutters(text: str) -> str:
    """Remove consecutive duplicate words.

    'we're we're going' -> 'we're going'
    'the the' -> 'the'

    Case-insensitive matching; keeps the first occurrence's casing.
    """

    def _dedup(match: re.Match) -> str:
        return match.group(1)

    # Match a word followed by one or more identical copies (case-insensitive).
    # The backreference \\1 with re.IGNORECASE handles mixed case.
    return re.sub(r"\b(\S+)(?:\s+\1)+\b", _dedup, text, flags=re.IGNORECASE)


def normalize_whitespace(text: str) -> str:
    """Collapse multiple spaces, fix whitespace around punctuation.

    - No space before period, comma, question mark, exclamation mark.
    - Space after period, comma, question mark, exclamation mark (unless end of string).
    - Collapse runs of whitespace to a single space.
    - Strip leading/trailing whitespace.
    """
    # Collapse multiple spaces/tabs into one space.
    text = re.sub(r"[ \t]+", " ", text)

    # Remove space before punctuation.
    text = re.sub(r"\s+([.,?!])", r"\1", text)

    # Ensure space after punctuation (if followed by a non-space, non-punctuation char).
    text = re.sub(r"([.,?!])([^\s.,?!])", r"\1 \2", text)

    # Collapse any remaining multiple spaces (can arise after previous subs).
    text = re.sub(r" {2,}", " ", text)

    return text.strip()
