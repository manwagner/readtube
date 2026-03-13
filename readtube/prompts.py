"""Prompt templates for different output modes."""

SYSTEM_PROMPT = """You are a skilled writer who transforms video transcripts into well-written, engaging articles.

Your task is to take a raw transcript and create a polished, magazine-style article that:
- Has a clear structure with headings and sections
- Captures the key ideas and insights
- Is easy to read and engaging
- Maintains the speaker's voice and perspective
- Uses proper formatting (markdown)

Do not include phrases like "In this video" or "The speaker says". Write as if it's an original article."""

ARTICLE_TEMPLATE = """Transform this transcript into a well-written article.

Title: {title}
Channel: {channel}
{chapter_context}
{timestamp_instructions}

Transcript:
{transcript}

Write a polished, magazine-style article based on this content. Use markdown formatting with headers, paragraphs, and occasional quotes from the original."""

ARTICLE_CHAPTERS_TEMPLATE = """Transform this transcript into a well-written article.

Title: {title}
Channel: {channel}

The transcript below is organized into sections with ## headings. Preserve these headings in your article. Write each section based on the content under that heading.
{timestamp_instructions}

Transcript:
{transcript}

Write a polished, magazine-style article based on this content. Use markdown formatting, keeping the ## section headings from the transcript. Write engaging prose for each section."""

TLDR_TEMPLATE = """Summarize this video transcript in 3-5 concise bullet points. Each bullet should capture one key idea. No fluff, no filler.

Title: {title}
Channel: {channel}

Transcript:
{transcript}"""

TAKEAWAYS_TEMPLATE = """Extract the key takeaways from this video transcript as a structured list. Group related points under topic headers. Include specific claims, data points, and actionable insights. Skip small talk and filler.

Title: {title}
Channel: {channel}

Transcript:
{transcript}"""

TIMESTAMP_INSTRUCTIONS = """
IMPORTANT: Preserve timestamps from the transcript. When referencing a key point, include the timestamp in the format [MM:SS] so readers can jump to that moment in the video. Place timestamps at major topic transitions and key claims."""


def get_prompt(
    mode: str,
    transcript: str,
    title: str,
    channel: str,
    chapters_text: str = "",
    has_chapter_structure: bool = False,
    timestamps: bool = False,
) -> tuple[str, str]:
    """Build the prompt for the given mode.

    Returns:
        (system_prompt, user_prompt) tuple.
    """
    timestamp_instructions = TIMESTAMP_INSTRUCTIONS if timestamps else ""

    if mode == "tldr":
        return SYSTEM_PROMPT, TLDR_TEMPLATE.format(
            title=title,
            channel=channel,
            transcript=transcript[:50000],
        )

    if mode == "takeaways":
        return SYSTEM_PROMPT, TAKEAWAYS_TEMPLATE.format(
            title=title,
            channel=channel,
            transcript=transcript[:50000],
        )

    # mode == "article" (default)
    if has_chapter_structure:
        return SYSTEM_PROMPT, ARTICLE_CHAPTERS_TEMPLATE.format(
            title=title,
            channel=channel,
            timestamp_instructions=timestamp_instructions,
            transcript=transcript[:50000],
        )

    chapter_context = ""
    if chapters_text:
        chapter_context = f"Chapters:\n{chapters_text}"

    return SYSTEM_PROMPT, ARTICLE_TEMPLATE.format(
        title=title,
        channel=channel,
        chapter_context=chapter_context,
        timestamp_instructions=timestamp_instructions,
        transcript=transcript[:50000],
    )
