import Foundation

/// LLM prompt templates ported verbatim from readtube/llm.py
enum PromptTemplates {
    static let systemPrompt = """
        You are a skilled writer who transforms video transcripts into well-written, engaging articles.

        Your task is to take a raw transcript and create a polished, magazine-style article that:
        - Has a clear structure with headings and sections
        - Captures the key ideas and insights
        - Is easy to read and engaging
        - Maintains the speaker's voice and perspective
        - Uses proper formatting (markdown)

        Do not include phrases like "In this video" or "The speaker says". Write as if it's an original article.
        """

    /// For videos without pre-structured chapter headings in the transcript.
    static func articlePrompt(
        title: String,
        channel: String,
        description: String,
        chapters: String,
        transcript: String
    ) -> String {
        let truncated = String(transcript.prefix(50_000))
        return """
            Transform this transcript into a well-written article.

            Title: \(title)
            Channel: \(channel)
            Description: \(description)
            Chapters:
            \(chapters)

            Transcript:
            \(truncated)

            Write a polished, magazine-style article based on this content. Use markdown formatting with headers, paragraphs, and occasional quotes from the original.
            """
    }

    /// For transcripts already structured with ## headings from chapter splitting.
    static func articlePromptWithChapters(
        title: String,
        channel: String,
        description: String,
        transcript: String
    ) -> String {
        let truncated = String(transcript.prefix(50_000))
        return """
            Transform this transcript into a well-written article.

            Title: \(title)
            Channel: \(channel)
            Description: \(description)

            The transcript below is organized into sections with ## headings. Preserve these headings in your article. Write each section based on the content under that heading.

            Transcript:
            \(truncated)

            Write a polished, magazine-style article based on this content. Use markdown formatting, keeping the ## section headings from the transcript. Write engaging prose for each section.
            """
    }
}
