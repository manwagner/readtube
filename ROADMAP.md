# Readtube Roadmap

## Done

- [x] Core CLI: `readtube URL` → article to stdout
- [x] Output formats: markdown, EPUB, PDF, HTML
- [x] Output modes: article, tldr, takeaways, transcript
- [x] 3 LLM backends: Ollama, Claude, OpenAI (all with streaming)
- [x] Auto-detection of available LLM backend
- [x] TOML config with CLI flag overrides
- [x] Chapter-aware transcript splitting
- [x] Timestamp linking (`--timestamps`)
- [x] Playlist and batch processing
- [x] Filesystem transcript cache with TTL
- [x] Proper Unix behavior (stdout=content, stderr=progress)
- [x] 87 tests, 13 source files, 2 core dependencies

---

## Phase 1 — Content Quality (highest impact)

The output quality is the product. Everything else is plumbing.

### Transcript cleaning
- [ ] Strip YouTube auto-caption artifacts: repeated words, "[music]", "[applause]"
- [ ] Remove filler words and stutters (uh, um, like, you know)
- [ ] Normalize whitespace and punctuation from auto-captions
- [ ] Detect and merge broken sentences from caption segmentation

### SponsorBlock integration
- [ ] Query SponsorBlock API (free, community-maintained) for sponsor segments
- [ ] Strip sponsor reads, self-promotion, and intro/outro before LLM processing
- [ ] Flag "interaction reminder" segments (like/subscribe) for removal
- [ ] Fallback gracefully when SponsorBlock has no data for a video

### Genre-aware prompts
- [ ] Auto-detect video genre: interview, lecture, tutorial, debate, documentary, podcast
- [ ] Use genre-specific prompt templates (an interview needs speaker attribution, a tutorial needs step-by-step structure, a lecture needs concept hierarchy)
- [ ] Allow `--genre` flag to override auto-detection
- [ ] Test each genre prompt against 10+ real videos and grade output quality

### Prompt iteration
- [ ] Build a test suite of 50+ videos across genres
- [ ] Grade output on: accuracy, readability, structure, completeness
- [ ] A/B test prompt variations systematically
- [ ] Document which prompts work best for which backends/models

---

## Phase 2 — Obsidian & Knowledge Workflow

Most target users are note-takers. Meet them where they are.

### Obsidian frontmatter
- [ ] `--frontmatter` flag that outputs YAML frontmatter: title, channel, date, URL, duration, tags
- [ ] Auto-generate tags from content (top 3-5 topics)
- [ ] Include video thumbnail as a markdown image reference
- [ ] Output reading time estimate in frontmatter

### Obsidian vault integration
- [ ] `readtube URL -o ~/Obsidian/Videos/` auto-names file as `{Channel} - {Title}.md`
- [ ] Detect existing files and skip (avoid duplicates in vault)
- [ ] Support `--template` for custom output templates (Obsidian callouts, dataview fields, etc.)

### Daily digest workflow
- [ ] Document the cron + readtube + Obsidian/Kindle workflow
- [ ] `readtube feed channels.txt` — process new videos from a list of channels (check against cache to skip already-processed)
- [ ] Output summary index file for batch runs (links to all generated articles)

---

## Phase 3 — Long Video Handling

A 3-hour podcast should work as well as a 10-minute explainer.

### Smart chunking
- [ ] Detect topic boundaries using sentence similarity when chapters aren't available
- [ ] Split long transcripts into coherent chunks that fit within LLM context windows
- [ ] Generate per-chunk summaries, then synthesize into a final article
- [ ] Show progress per chunk during generation

### Multi-pass generation
- [ ] First pass: structured outline from full transcript
- [ ] Second pass: expand each section with detail from relevant transcript chunks
- [ ] Combine into final article with consistent voice and flow
- [ ] `--depth` flag: shallow (single pass) vs deep (multi-pass)

### Context window management
- [ ] Detect model context limits per backend
- [ ] Auto-select chunking strategy based on transcript length vs context window
- [ ] Warn when transcript is too long for the selected model

---

## Phase 4 — Distribution & Packaging

Go from "works on my machine" to "anyone can install it."

### PyPI release
- [ ] Clean up pyproject.toml metadata
- [ ] Write a proper README with install instructions and examples
- [ ] Publish to PyPI: `pip install readtube`
- [ ] Set up GitHub Actions for automated release on tag

### Homebrew / Nix
- [ ] Create Homebrew formula
- [ ] Update shell.nix for the new simplified package
- [ ] Document installation for each method

### Single binary (optional)
- [ ] Investigate PyInstaller or Nuitka for standalone binary
- [ ] Evaluate tradeoffs (binary size vs install simplicity)

---

## Phase 5 — Kindle & E-Reader Pipeline

Reading on e-readers is a primary use case. Make it frictionless.

### Send-to-Kindle
- [ ] `--kindle` flag that generates EPUB and emails to Kindle address
- [ ] Configure Kindle email in config.toml
- [ ] Support Amazon's Send to Kindle email API
- [ ] Batch send: process playlist → email all as a single digest EPUB

### EPUB quality
- [ ] Improve EPUB typography and metadata
- [ ] Embed cover images properly (currently works but could be better)
- [ ] Support custom CSS for EPUB via config
- [ ] Test on actual Kindle devices and Kobo readers

---

## Phase 6 — Cross-Video Intelligence

This is where it gets interesting. Once you have 50+ articles, the collection becomes more valuable than any single article.

### Search across articles
- [ ] `readtube search "topic"` — full-text search across all generated articles
- [ ] Index articles at generation time (SQLite FTS5 or tantivy)
- [ ] Return relevant snippets with source video links

### Q&A over your library
- [ ] `readtube ask "What did these videos say about X?"` — RAG over your article collection
- [ ] Simple approach first: stuff top-5 relevant chunks into LLM context
- [ ] Optional: local vector store for embedding-based retrieval
- [ ] Cite sources: include video title and timestamp for each claim

### Related content linking
- [ ] After generating an article, find related articles in your library
- [ ] Append "Related" section with links to similar content
- [ ] Use for Obsidian backlinks and graph view

---

## Phase 7 — Alternative Inputs

YouTube isn't the only source of video content worth reading.

### Podcast support
- [ ] Accept podcast RSS feed URLs
- [ ] Download audio, transcribe via Whisper (local) or cloud API
- [ ] Same pipeline: transcript → article → output

### Local video files
- [ ] `readtube file.mp4` — transcribe local video with Whisper
- [ ] Support common formats: mp4, mkv, webm, mp3
- [ ] Cache transcriptions by file hash

### Other platforms
- [ ] Vimeo, Twitch VODs, Twitter/X spaces (via yt-dlp, which already supports many)
- [ ] Conference talk archives (many use YouTube, but some don't)

---

## Non-Goals

Things we deliberately won't build:

- **GUI / web app** — the CLI is the product. Read in Obsidian, Kindle, your browser.
- **User accounts / cloud sync** — local-first. Your filesystem is your database.
- **Real-time processing** — batch is fine. Videos don't change after upload.
- **Social features** — no sharing, no comments, no feeds. Pipe output to whatever you want.
- **Translation** — use dedicated tools. We generate, you translate.
- **TTS** — use dedicated tools. We generate text, you feed it to your TTS of choice.
