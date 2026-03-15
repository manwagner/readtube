# Readtube Roadmap

**Vision:** The best way to turn video into text you actually want to read.

Not a note-taking app. Not a transcription service. A tool that produces
articles good enough that you forget they started as videos. Local-first,
Unix-native, zero accounts.

**Unique edge:** Timestamp-linked articles. Every claim traces back to
the exact moment in the video. No other tool does this.

---

## Done

- [x] Single video → article: `readtube URL`
- [x] Output modes: `--mode article|tldr|takeaways|transcript`
- [x] Output formats: `-o file.md|.epub|.pdf|.html`
- [x] Streaming LLM output to terminal in real time
- [x] 3 LLM backends: Ollama, Claude, OpenAI with auto-detection
- [x] Chapter-aware transcript splitting
- [x] Timestamp linking: `--timestamps` → `[4:32](youtube.com/...&t=272)`
- [x] Playlist processing: `readtube playlist URL`
- [x] Batch processing: `readtube batch urls.txt`
- [x] TOML config: `~/.config/readtube/config.toml`
- [x] Transcript caching: filesystem JSON, configurable TTL
- [x] Unix pipeline support: stdout=content, stderr=progress, exit codes
- [x] 87 tests passing
- [x] 13 source files, 2,287 lines, 2 core dependencies

---

## Phase 1 — Content Quality

**Why first:** Output quality IS the product. Every hour spent here is
worth 10 hours anywhere else.

**Success metric:** 50 videos across genres, human-rated 4+/5 on
accuracy, readability, and structure.

### 1.1 Transcript Cleaning

- [ ] Create `readtube/clean.py` module
- [ ] Strip caption artifacts: `[music]`, `[applause]`, `[laughter]`, `[Music]`
- [ ] Remove repeated words from segment boundaries ("we're we're" → "we're")
- [ ] Remove filler words: uh, um, you know, like (as filler), basically, sort of, kind of, I mean
- [ ] Merge broken sentences across caption segment boundaries
- [ ] Normalize whitespace and punctuation
- [ ] Integrate into `pipeline.py` after transcript fetch, before prompt building
- [ ] Add `--raw` CLI flag to skip cleaning
- [ ] Preserve segment `start` and `duration` fields for timestamp support
- [ ] Write tests for each cleaning step
- [ ] Test against 5+ real YouTube auto-caption transcripts

### 1.2 SponsorBlock Integration

- [ ] Create `readtube/sponsorblock.py` module
- [ ] HTTP GET to `https://sponsor.ajay.app/api/skipSegments?videoID=ID`
- [ ] Parse response: extract segment start/end times and categories
- [ ] Filter categories: sponsor, selfpromo, interaction, intro, outro
- [ ] Remove transcript segments that fall within sponsor time ranges
- [ ] Handle partial overlaps (segment starts before sponsor, ends during)
- [ ] Integrate into `pipeline.py` after transcript fetch, before cleaning
- [ ] Add `--no-sponsorblock` CLI flag to disable
- [ ] Graceful fallback: return unmodified transcript when API unreachable (timeout 3s)
- [ ] Graceful fallback: return unmodified transcript when video has no data (404)
- [ ] Write tests with mocked API responses
- [ ] Test against 5+ popular videos known to have sponsors

### 1.3 Speaker Identification

- [ ] Extract speaker names from video title (e.g., "Lex Fridman & Andrej Karpathy")
- [ ] Extract speaker names from video description
- [ ] Extract speaker names from chapter titles
- [ ] Detect speaker changes from transcript cues: name mentions, "as X said"
- [ ] Heuristic diarization: use pause length between segments as turn-taking signal
- [ ] Format output with attribution: `**Speaker:** text`
- [ ] Add `--speakers "Alice,Bob"` CLI flag for manual override
- [ ] Only activate for interview/podcast/panel genres (integrate with genre detection)
- [ ] Write tests for name extraction from titles and descriptions
- [ ] Test against 5+ interview/podcast videos

### 1.4 Genre-Aware Prompts

- [ ] Create `readtube/genre.py` module
- [ ] Detect genre from title keywords (tutorial, interview, lecture, etc.)
- [ ] Detect genre from channel name patterns (known podcast channels, etc.)
- [ ] Detect genre from description patterns
- [ ] Detect genre from transcript patterns (Q&A flow, step-by-step language, etc.)
- [ ] Write interview/podcast prompt template (speaker attribution, Q&A flow, key quotes)
- [ ] Write tutorial prompt template (step-by-step, code blocks, prerequisites)
- [ ] Write lecture prompt template (concept hierarchy, definitions, progression)
- [ ] Write documentary prompt template (narrative arc, chronology, context)
- [ ] Write debate/panel prompt template (multiple viewpoints, agreement/disagreement)
- [ ] Write conference talk prompt template (problem → solution → results)
- [ ] Add `--genre` CLI flag to override detection
- [ ] Add `--list-genres` CLI flag to show available genres
- [ ] Integrate genre detection into `pipeline.py`
- [ ] Write tests for genre detection heuristics
- [ ] Test each prompt template against 3+ real videos of that genre

### 1.5 Description & Metadata Enrichment

Video descriptions contain links, timestamps, context, and corrections
that never appear in the transcript. This is free data we're ignoring.

- [ ] Parse video description for timestamped sections
- [ ] Extract links from description and include as references in article
- [ ] Extract corrections/errata from description ("correction at 12:30...")
- [ ] Include description context in LLM prompt (channel bio, video summary, links)
- [ ] Parse pinned comment for additional context (many creators pin corrections/links)
- [ ] Merge description timestamps with chapter data when chapters are missing
- [ ] Write tests for description parsing

### 1.6 Multi-Language Transcript Support

- [ ] Auto-detect best available transcript language when `--lang` not specified
- [ ] Prefer manual captions over auto-generated when both exist
- [ ] List available languages: `readtube URL --list-languages`
- [ ] Handle videos with multiple language tracks gracefully
- [ ] Inform user on stderr which language/type was selected
- [ ] Write tests for language selection logic

### 1.7 Custom Prompts

- [ ] Add `--prompt "..."` CLI flag
- [ ] Inject transcript, title, channel into custom prompt automatically
- [ ] Add `--prompt-file path/to/prompt.txt` for reusable templates
- [ ] Create 5-10 example prompt files (study guide, book list, code examples, debate summary, etc.)
- [ ] Ship examples to `~/.config/readtube/prompts/` on `config --init`
- [ ] Document custom prompt syntax in README
- [ ] Write tests for custom prompt flag handling

### 1.8 Prompt Evaluation Framework

- [ ] Curate test video list: 8-10 per genre, 50+ total, ranging 5 min to 2+ hours
- [ ] Store test video list as JSON/TOML in repo
- [ ] Build `readtube eval` subcommand
- [ ] `readtube eval` runs all test videos and saves outputs to `eval/` directory
- [ ] `readtube eval --genre tutorial` to run only one genre
- [ ] Define scoring rubric: accuracy, readability, structure, completeness (1-5 each)
- [ ] LLM-as-judge: second LLM call auto-scores output against rubric
- [ ] Save eval results as JSON with scores, timestamps, model info
- [ ] `readtube eval --compare run1.json run2.json` to diff two eval runs
- [ ] Track scores over time (append to eval log)
- [ ] Document which models produce best results per genre

---

## Phase 2 — Visual Intelligence

**Why second:** Transcripts capture ~50% of video content. Slides, code,
diagrams, equations, whiteboard drawings are invisible to transcript-only
processing.

**Success metric:** Articles from slide-heavy talks contain information
that only appeared visually.

### 2.1 Key Frame Extraction

- [ ] Download video via yt-dlp (only when `--frames` flag is set)
- [ ] Extract frames at chapter boundary timestamps using ffmpeg
- [ ] Extract frames at fixed intervals (e.g., every 30 seconds) as fallback
- [ ] Detect slide transitions using perceptual frame difference hashing
- [ ] Deduplicate near-identical frames (cosine similarity on frame hash)
- [ ] Save frames as PNG with timestamp in filename: `frame_0432.png`
- [ ] Cache extracted frames in `~/.cache/readtube/frames/{video_id}/`
- [ ] Add `--frames` CLI flag (off by default)
- [ ] Write tests for frame deduplication logic

### 2.2 Vision Model Integration

- [ ] Detect if current LLM backend supports vision (Claude, GPT-4V, LLaVA)
- [ ] Send key frames to vision model with transcript context at matching timestamp
- [ ] Prompt: "Here's what was said at [MM:SS]. Here's what was shown. Synthesize."
- [ ] Extract from frames: slide text, code snippets, diagram descriptions, chart data
- [ ] Merge vision-extracted content with transcript before article generation
- [ ] Fall back to transcript-only if vision model unavailable
- [ ] Write tests with mock vision model responses

### 2.3 Code Extraction

- [ ] Detect frames likely containing code (dark background, syntax highlighting, monospace)
- [ ] Send code-containing frames to vision model with "extract the code" prompt
- [ ] Format extracted code as ``` blocks with language detection
- [ ] Reconstruct full examples from incremental frames (diff-based merging)
- [ ] Add `--extract-code` CLI flag for code-focused output
- [ ] Write tests for code frame detection heuristic

### 2.4 Embedded Screenshots

- [ ] Embed frames in markdown: `![Slide: description](frame_0432.png)`
- [ ] Embed frames in EPUB as inline images
- [ ] Embed frames in HTML as base64 or referenced images
- [ ] Add `--screenshot-dir` CLI flag to control frame output location
- [ ] Auto-generate alt text from vision model content extraction
- [ ] Write tests for image embedding in each output format

---

## Phase 3 — Long Videos

**Why third:** 1+ hour videos (podcasts, lectures, conference talks) are
highest-value but produce worst output due to context window overflow.

**Success metric:** A 3-hour podcast produces an article as good as a
15-minute video does today.

### 3.1 Context Window Management

- [ ] Map context limits per model: Claude (known), OpenAI (known), Ollama (query `/api/show`)
- [ ] Estimate token count before sending (tiktoken for OpenAI, word-count heuristic for others)
- [ ] When transcript fits context: send as-is (current behavior)
- [ ] When transcript exceeds context: auto-trigger chunked generation
- [ ] Add `--max-tokens` CLI flag to override context detection
- [ ] Log token count and strategy choice to stderr
- [ ] Write tests for token estimation and strategy selection

### 3.2 Chunked Generation

- [ ] Split transcript at chapter boundaries (preferred)
- [ ] Split at topic boundaries for unchaptered videos (paragraph-level heuristic)
- [ ] Implement sliding-window overlap (last N sentences of chunk N appear in chunk N+1)
- [ ] Generate section summary for each chunk via LLM
- [ ] Synthesis pass: combine chunk summaries into coherent final article
- [ ] Preserve chapter headings across chunks
- [ ] Preserve timestamp references across chunks
- [ ] Show per-chunk progress on stderr: `generating [3/7]...`
- [ ] Write tests for chunking logic and boundary detection

### 3.3 Multi-Pass Generation

- [ ] Add `--depth shallow|deep` CLI flag (default: auto based on duration)
- [ ] Auto-select: single-pass for <60 min, multi-pass for 60+ min
- [ ] Pass 1: generate structured outline from full transcript or chunk summaries
- [ ] Pass 2: expand each outline section using relevant transcript chunks
- [ ] Pass 3: edit pass for consistency, flow, deduplication
- [ ] Show pass progress on stderr: `pass 1/3: outlining...`
- [ ] Write tests for multi-pass orchestration

### 3.4 Cost Estimation & Budget Control

- [ ] Store per-model pricing data (input/output per 1K tokens)
- [ ] Add `--estimate` CLI flag: show token count and estimated cost, then exit
- [ ] Print estimated cost to stderr before generation on paid APIs
- [ ] Add `--budget N` CLI flag: abort if estimated cost exceeds $N
- [ ] Track cumulative usage in `~/.local/share/readtube/usage.json`
- [ ] Build `readtube usage` subcommand: show tokens/cost by backend and time period
- [ ] Update pricing data with each readtube release
- [ ] Write tests for cost estimation logic

### 3.5 Pre-Summarization for Cost Savings

For very long videos on paid APIs, summarize chunks locally (Ollama)
before sending to a cloud model for the final synthesis.

- [ ] Detect when local model is available alongside paid API
- [ ] Pre-summarize transcript chunks with local model to reduce token count
- [ ] Send condensed summaries to paid API for final article generation
- [ ] Add `--pre-summarize` CLI flag (auto when local + cloud both configured)
- [ ] Show cost comparison on stderr: "pre-summarized: ~$0.08 vs full: ~$0.45"
- [ ] Write tests for pre-summarization pipeline

---

## Phase 4 — Structured Data Extraction

**Why fourth:** Videos contain structured information more useful as data
than prose — books, people, tools, claims, URLs. This powers search,
cross-referencing, and integration with other tools.

**Success metric:** `readtube URL --extract entities` produces parseable
JSON that scripts can use to build reading lists or knowledge graphs.

### 4.1 Entity Extraction

- [ ] Add `--extract entities` mode
- [ ] Extract: people, organizations, books, papers, tools/software, URLs, dates
- [ ] Each entity: name, context (why mentioned), timestamp, confidence score
- [ ] Output as JSON (`--format json`) or markdown table (default)
- [ ] Design stable JSON schema and document it
- [ ] Write tests with known videos and expected entities

### 4.2 Claim Extraction

- [ ] Add `--extract claims` mode
- [ ] Each claim: statement, evidence given, timestamp, speaker (if identified)
- [ ] Add `--extract claims --verify` flag: LLM flags dubious claims
- [ ] Output as JSON or markdown
- [ ] Write tests with known videos and expected claims

### 4.3 Reference Extraction

- [ ] Add `--extract references` mode
- [ ] Parse video description for links and timestamps
- [ ] Parse pinned comment for links (YouTube Data API or scraping)
- [ ] Extract books/papers/URLs mentioned in transcript
- [ ] Deduplicate across description, transcript, and comments
- [ ] Output as markdown bibliography, BibTeX, or JSON
- [ ] Write tests for description/comment parsing

### 4.4 Obsidian-Native Output

- [ ] Add `--frontmatter` CLI flag
- [ ] Generate YAML frontmatter: title, channel, date, URL, duration, tags, reading_time
- [ ] Auto-generate tags from extracted entities and topics
- [ ] Add Dataview-compatible fields
- [ ] Generate wikilinks: `[[Geoffrey Hinton]]`, `[[Deep Learning (book)]]`
- [ ] Auto-name output files: `{Channel} - {Title}.md`
- [ ] Skip already-generated files in output directory
- [ ] Write tests for frontmatter generation

---

## Phase 5 — Knowledge Workflow

**Why fifth:** With quality articles and structured data, help users
build a personal knowledge base from 100+ processed videos.

**Success metric:** Find any piece of information across 100+ articles
in under 10 seconds.

### 5.1 Channel Feeds

- [ ] Build `readtube feed` subcommand
- [ ] Parse `channels.txt`: one handle/URL per line, `#` comments
- [ ] Fetch latest N videos per channel via yt-dlp
- [ ] Track processed video IDs in `~/.local/share/readtube/processed.json`
- [ ] Skip already-processed videos
- [ ] Process new videos with configured defaults (mode, format, frontmatter)
- [ ] Concurrent fetching: N channels in parallel
- [ ] Write tests for feed parsing and deduplication

### 5.2 Search

- [ ] Build `readtube search` subcommand
- [ ] Create SQLite FTS5 index alongside cache
- [ ] Index articles at generation time (title, content, entities)
- [ ] `readtube search "query"` returns: filename, snippet, source video link
- [ ] `readtube search "query" --format json` for programmatic use
- [ ] Search across entity extractions (find videos mentioning a person/book)
- [ ] Highlight matching terms in snippets
- [ ] Write tests for indexing and search

### 5.3 Cross-Video Q&A

- [ ] Build `readtube ask` subcommand
- [ ] Find relevant articles via FTS5 search index
- [ ] Rank and select top-N relevant chunks
- [ ] Stuff chunks into LLM context with source attribution
- [ ] Generate answer with citations: `[Source: "Title" by Channel, MM:SS]`
- [ ] Add `--sources` flag to show which articles were consulted
- [ ] Write tests with mock index and LLM responses

### 5.4 Topic Clustering

- [ ] Build `readtube topics` subcommand
- [ ] Analyze all processed articles and group by topic
- [ ] Show per topic: name, video count, key speakers, timeline
- [ ] `readtube topics "machine learning"` for deep dive into one topic
- [ ] Generate topic summary synthesizing insights from multiple sources
- [ ] Write tests for clustering logic

---

## Phase 6 — Performance & Reliability

**Why sixth:** Make batch processing fast and bulletproof. 100 videos
overnight, zero manual intervention.

**Success metric:** 100 videos processed overnight with zero failures
requiring manual intervention.

### 6.1 Concurrent Processing

- [ ] Add `--jobs N` CLI flag (default: 3)
- [ ] Process N videos in parallel using ThreadPoolExecutor or asyncio
- [ ] Respect rate limits per backend (YouTube, SponsorBlock, LLM API)
- [ ] Shared progress display: `[12/100] processing "Title"...`
- [ ] Fail gracefully per video: log error, continue with remaining
- [ ] Skip already-completed videos on resume
- [ ] Write tests for concurrent execution and error isolation

### 6.2 Retry & Resilience

- [ ] Exponential backoff with jitter for all HTTP calls (extend existing)
- [ ] Circuit breaker: pause after N consecutive failures, warn user
- [ ] Add `--retry N` CLI flag for max retries per video
- [ ] Separate strategies: transient (network, rate limit) vs permanent (video deleted)
- [ ] `readtube batch --resume` picks up where failed batch left off
- [ ] Save batch state to `~/.local/share/readtube/batch_state.json`
- [ ] Write tests for retry logic and circuit breaker

### 6.3 Output Caching

- [ ] Cache generated articles by hash of (transcript + prompt template + model)
- [ ] Regenerate only when prompt, model, or transcript changes
- [ ] Add `--force` CLI flag to bypass article cache
- [ ] Invalidate cache when readtube version changes prompt templates
- [ ] Write tests for cache hit/miss logic

### 6.4 Progress & Reporting

- [ ] Rich stderr progress: current step, ETA, token counts
- [ ] `--quiet` flag: suppress all progress (already exists, verify behavior)
- [ ] `--json-progress` flag: machine-readable progress on stderr
- [ ] Batch summary report: N processed, N failed, N skipped, total tokens, total cost
- [ ] Write tests for progress output formatting

### 6.5 Config Profiles

- [ ] Add `[profiles]` section to config.toml
- [ ] `readtube --profile kindle` loads preset (epub + dark theme + chapters)
- [ ] `readtube --profile obsidian` loads preset (md + frontmatter + timestamps)
- [ ] `readtube --profile quick` loads preset (tldr + no chapters)
- [ ] Users can define custom profiles in config.toml
- [ ] Profile settings merge with (and override) defaults
- [ ] Write tests for profile loading and merging

### 6.6 Shell Completions

- [ ] Generate Bash completions (flags, modes, backends, genres)
- [ ] Generate Zsh completions
- [ ] Generate Fish completions
- [ ] `readtube --completions bash|zsh|fish` outputs completion script
- [ ] Document installation in README

### 6.7 Pipeline Hooks

- [ ] Add `[hooks]` section to config.toml
- [ ] `post_transcript` hook: run shell command after transcript fetch
- [ ] `post_article` hook: run shell command after article generation
- [ ] `post_render` hook: run shell command after file output
- [ ] Pass video metadata and output path as environment variables to hooks
- [ ] Example: `post_render = "cp {output} ~/Obsidian/Videos/"`
- [ ] Write tests for hook execution

---

## Phase 7 — E-Reader Pipeline

**Why seventh:** E-readers are where long-form reading happens. EPUB
exists but the workflow has friction.

### 7.1 Send-to-Kindle

- [ ] Add `--kindle` CLI flag
- [ ] Generate EPUB, then email to Kindle address
- [ ] Add `kindle_email` setting in config.toml
- [ ] Add SMTP config in config.toml (host, port, user, password_env)
- [ ] Support system `sendmail` as alternative to SMTP
- [ ] Batch: `readtube playlist URL --kindle` sends digest EPUB
- [ ] Write tests for email construction (mock SMTP)

### 7.2 EPUB Polish

- [ ] Test on real Kindle device
- [ ] Test on real Kobo device
- [ ] Test on Apple Books
- [ ] Improve cover image: use hi-res YouTube thumbnail
- [ ] Better table of contents for multi-chapter articles
- [ ] Add `--theme` support for EPUB (already works for HTML)
- [ ] Add custom CSS via config.toml `[epub]` section
- [ ] Embed extracted screenshots in EPUB (from Phase 2)
- [ ] Fix any rendering issues found in device testing

### 7.3 Accessibility

- [ ] Auto-generate alt text for all embedded images and screenshots
- [ ] Ensure EPUB passes epubcheck accessibility validation
- [ ] Proper heading hierarchy in all output formats (h1 → h2 → h3, no skips)
- [ ] Semantic HTML in HTML output (article, section, figure, figcaption)
- [ ] Screen reader friendly timestamp links (aria-label with full description)
- [ ] Write tests for heading hierarchy and HTML semantics

### 7.4 Digest Mode

- [ ] Build `readtube digest` subcommand
- [ ] Accept channels.txt or list of URLs
- [ ] Combine multiple articles into single EPUB with table of contents
- [ ] Add entity index at back (all people, books, tools across articles)
- [ ] One email to Kindle with `--kindle` flag
- [ ] Write tests for multi-article EPUB construction

---

## Phase 8 — Distribution

**Why eighth:** Build for yourself first, distribute when it's good.

### 8.1 PyPI

- [ ] Clean up pyproject.toml metadata (description, classifiers, URLs)
- [ ] Publish to PyPI: `pip install readtube`
- [ ] Optional extras: `readtube[epub]`, `readtube[claude]`, `readtube[vision]`, `readtube[all]`
- [ ] GitHub Actions: run tests on push
- [ ] GitHub Actions: publish to PyPI on tag
- [ ] Write comprehensive README: install, quickstart, config reference, examples

### 8.2 Homebrew

- [ ] Create Homebrew tap: `unbalancedparentheses/readtube`
- [ ] Write formula with dependencies
- [ ] `brew install unbalancedparentheses/readtube/readtube`
- [ ] Auto-update formula on GitHub release

### 8.3 Nix

- [ ] Update flake.nix for current package structure
- [ ] Update shell.nix for development environment
- [ ] Set up Cachix for pre-built binaries
- [ ] Test on NixOS

### 8.4 Docker

- [ ] Write Dockerfile with yt-dlp, ffmpeg, and all optional dependencies
- [ ] `docker run readtube URL` works out of the box
- [ ] Mount volume for config and cache persistence
- [ ] Publish to Docker Hub or GitHub Container Registry
- [ ] GitHub Actions: build and push image on release

---

## Phase 9 — Alternative Inputs

**Why last:** YouTube covers 90% of the use case. Expand only after
the core is excellent.

### 9.1 Local Video/Audio Files

- [ ] Detect local file path vs URL in CLI argument
- [ ] Transcribe video with Whisper (local via whisper.cpp or API via OpenAI)
- [ ] Transcribe audio-only files (.mp3, .m4a, .wav)
- [ ] Add `--whisper-model` CLI flag (tiny, base, small, medium, large)
- [ ] Cache transcriptions by file content hash (SHA256)
- [ ] Write tests for file detection and Whisper integration

### 9.2 Podcasts

- [ ] Build `readtube podcast` subcommand
- [ ] Parse RSS feed URL to get episode list
- [ ] Episode selection: `--latest`, `--episode N`, `--all`
- [ ] Download audio from RSS enclosure URL
- [ ] Transcribe via Whisper, then normal pipeline
- [ ] Speaker diarization for interview podcasts (heuristic or pyannote)
- [ ] Write tests for RSS parsing and episode selection

### 9.3 Other Platforms

- [ ] Test yt-dlp extraction on Vimeo (transcript + metadata)
- [ ] Test yt-dlp extraction on Twitch VODs
- [ ] Test yt-dlp extraction on Twitter/X spaces
- [ ] Test yt-dlp extraction on Bilibili
- [ ] Document which platforms work out of the box
- [ ] Add platform-specific metadata extraction where needed
- [ ] Write integration tests for each supported platform

### 9.4 Live Stream Archives

- [ ] Detect live stream archives from YouTube metadata
- [ ] Handle 4-12 hour durations via aggressive chunking
- [ ] Extract highlights from chat replay timestamps (high-activity moments)
- [ ] Add `--highlights-only` flag for long streams
- [ ] Write tests for stream detection and highlight extraction

---

## Non-Goals

- **GUI / web app.** CLI is the product. Read in Obsidian, Kindle, your browser.
- **User accounts / cloud.** Local-first. No servers, no subscriptions.
- **Real-time / streaming video.** We process finished content.
- **Social features.** No sharing, feeds, or recommendations.
- **Translation.** Use DeepL, Google Translate, or your LLM.
- **TTS.** Use Eleven Labs, macOS `say`, or your preferred tool.
- **Competing with Notion/Readwise.** We generate files for YOUR workflow.
- **Perfect diarization.** Heuristics, not ML models. Good enough, not perfect.

---

## Principles

1. **Output quality over feature count.** One excellent mode beats five mediocre ones.
2. **Composable over integrated.** Pipe to grep, jq, Obsidian, Kindle, whatever.
3. **Local over cloud.** Ollama is default. Cloud APIs are opt-in.
4. **Fewer dependencies over more.** Core: yt-dlp + youtube-transcript-api. Everything else optional.
5. **Transparent over magic.** Cache hits, backend, token counts, progress — all visible on stderr.
6. **Data over prose.** Articles are default, but structured data (entities, claims) is often more useful.
7. **Fail gracefully, recover automatically.** Errors never lose work or require manual intervention in batch mode.
