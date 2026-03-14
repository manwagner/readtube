# Readtube Roadmap

**Vision:** The best way to turn video into text you actually want to read.

Not a note-taking app. Not a transcription service. A tool that produces
articles good enough that you forget they started as videos. Local-first,
Unix-native, zero accounts.

**Unique edge:** Timestamp-linked articles. Every claim traces back to
the exact moment in the video. No other tool does this.

---

## What's Built

| Feature | Status | Command |
|---------|--------|---------|
| Single video → article | Done | `readtube URL` |
| Multiple output modes | Done | `--mode article\|tldr\|takeaways\|transcript` |
| Output formats | Done | `-o file.md\|.epub\|.pdf\|.html` |
| Streaming LLM output | Done | Streams to terminal in real time |
| 3 LLM backends | Done | Ollama, Claude, OpenAI (auto-detected) |
| Chapter-aware splitting | Done | Uses video chapters for article structure |
| Timestamp linking | Done | `--timestamps` → `[4:32](youtube.com/...&t=272)` |
| Playlist processing | Done | `readtube playlist URL` |
| Batch processing | Done | `readtube batch urls.txt` |
| TOML config | Done | `~/.config/readtube/config.toml` |
| Transcript caching | Done | Filesystem JSON, configurable TTL |
| Unix pipeline support | Done | stdout=content, stderr=progress, exit codes |

13 source files. 2,287 lines. 87 tests. 2 core dependencies.

---

## Phase 1 — Content Quality

**Why first:** Output quality IS the product. A tool that produces bad
articles is worthless no matter how many features it has. Every hour
spent here is worth 10 hours spent anywhere else.

**Success metric:** Run readtube against 50 videos across genres.
A human rates each output 1-5 on accuracy, readability, and structure.
Average score should be 4+.

### 1.1 Transcript Cleaning

Raw YouTube auto-captions are noisy. The LLM wastes tokens processing
garbage and sometimes reproduces it in the output.

```
Before: "so uh what we're we're going to do is um [music] basically uh"
After:  "What we're going to do is basically"
```

- [ ] Strip caption artifacts: `[music]`, `[applause]`, `[laughter]`, repeated words
- [ ] Remove filler: uh, um, like, you know, basically, right, so (when used as filler)
- [ ] Merge broken sentences from caption segmentation boundaries
- [ ] Normalize punctuation and whitespace
- [ ] Add `--raw` flag to skip cleaning (for debugging or when manual captions are good)

Effort: Small. One new module, ~100 lines. Regex + heuristics.

### 1.2 SponsorBlock Integration

The kamikaze test video included a full "Heroes of History" ad read in
its takeaways. Sponsor segments should never reach the LLM.

[SponsorBlock API](https://wiki.sponsor.ajay.app/w/API_Docs) is free,
community-maintained, and covers most popular videos.

- [ ] Query SponsorBlock for segment timestamps before processing
- [ ] Strip categories: sponsor, selfpromo, interaction (like/subscribe), intro, outro
- [ ] Remove matching transcript segments by timestamp range
- [ ] `--no-sponsorblock` flag to disable
- [ ] Graceful fallback when API is unreachable or has no data

Effort: Small. One HTTP call, timestamp-range filtering on transcript segments.

### 1.3 Speaker Identification

Half of YouTube's best content is conversations — podcasts, interviews,
panels, debates. Without knowing who said what, the article is a mess
of unattributed claims.

- [ ] Extract speaker names from video title, description, and chapter titles
- [ ] Use transcript cues for speaker changes (name mentions, "as X said", turn-taking patterns)
- [ ] Format output with speaker attribution: `**Lex Fridman:** ...` or `> "Quote" — Andrej Karpathy`
- [ ] For auto-captions: heuristic diarization based on pause length and topic shifts
- [ ] `--speakers "Alice,Bob"` flag to manually specify speaker names
- [ ] Integrate with genre detection — only activate for interview/podcast/panel genres

Effort: Medium. Heuristic-based is achievable. Perfect diarization is hard.

### 1.4 Genre-Aware Prompts

An interview, a tutorial, and a documentary need fundamentally different
article structures. A single generic prompt can't serve all three well.

| Genre | What the article needs |
|-------|----------------------|
| Interview/podcast | Speaker attribution, Q&A flow, key quotes |
| Tutorial | Step-by-step structure, code blocks, prerequisites |
| Lecture | Concept hierarchy, definitions, logical progression |
| Documentary | Narrative arc, chronology, context |
| Debate/panel | Multiple viewpoints, areas of agreement/disagreement |
| Conference talk | Problem → solution → results, speaker bio context |

- [ ] Auto-detect genre from title, description, channel, and transcript patterns
- [ ] 6 genre-specific prompt templates
- [ ] `--genre` flag to override detection
- [ ] `--list-genres` to show available genres

Effort: Medium. Genre detection is heuristic. Prompt tuning is iterative.

### 1.5 Custom Prompts via Natural Language

Fixed modes (article/tldr/takeaways) cover 80% of use cases. The other
20% is where users get creative. Let them describe what they want.

```bash
readtube URL --prompt "Extract every book and paper mentioned, with context for why it was recommended"
readtube URL --prompt "List all Python code examples shown, with explanations"
readtube URL --prompt "Create a study guide with key terms and quiz questions"
readtube URL --prompt "Summarize the debate positions and who won each point"
```

- [ ] `--prompt "..."` flag that replaces the system template with user's instruction
- [ ] Inject transcript, title, channel into user's prompt automatically
- [ ] `--prompt-file prompts/study-guide.txt` for reusable prompt templates
- [ ] Ship 5-10 example prompts in `~/.config/readtube/prompts/`

Effort: Small. The plumbing exists. This is just a new prompt pathway.

### 1.6 Prompt Evaluation Framework

Prompts can't be improved without measurement.

- [ ] Curate 50+ test videos: 8-10 per genre, ranging from 5 min to 2+ hours
- [ ] Build `readtube eval` command that runs all test videos and saves outputs
- [ ] Score rubric: accuracy (are facts correct?), readability (would you read this?), structure (headings/flow make sense?), completeness (key points covered?)
- [ ] LLM-as-judge: use a second LLM call to auto-score outputs against rubric
- [ ] Track scores over time as prompts are iterated (JSON log of eval runs)
- [ ] `readtube eval --compare` to diff two eval runs side by side
- [ ] Document which models produce best results per genre

Effort: Medium. The framework is simple. The iteration is ongoing.

---

## Phase 2 — Visual Intelligence

**Why second:** Transcripts capture maybe 50% of what's in a video.
The other 50% is on screen — slides, code, diagrams, equations,
whiteboard drawings, terminal output. A lecture about neural networks
shows architecture diagrams. A coding tutorial shows the actual code.
A conference talk has slides with data. None of this is in the transcript.

**Success metric:** Articles from slide-heavy talks and coding tutorials
should contain information that only appeared visually, not verbally.

### 2.1 Key Frame Extraction

- [ ] Extract frames at chapter boundaries, slide transitions, and fixed intervals
- [ ] Detect slide transitions using frame difference hashing (no ML needed)
- [ ] Deduplicate near-identical frames (talking head hasn't moved)
- [ ] `--frames` flag to enable (off by default — requires downloading video)
- [ ] Cache extracted frames alongside transcript cache

### 2.2 Vision Model Integration

- [ ] Send key frames to vision-capable LLM (Claude, GPT-4V, LLaVA via Ollama)
- [ ] Extract: slide text, code snippets, diagram descriptions, data from charts
- [ ] Merge visual content with transcript at matching timestamps
- [ ] Prompt structure: "Here's what was said at [12:30]. Here's what was shown on screen. Synthesize."

### 2.3 Code Extraction

Programming tutorials are the highest-demand use case for visual extraction.

- [ ] Detect code on screen (syntax highlighting, monospace font, terminal background)
- [ ] Extract code as properly formatted code blocks with language detection
- [ ] Reconstruct full code examples from multiple incremental frames
- [ ] Include code in article as ```language blocks at the right section
- [ ] `--extract-code` flag for code-focused output

### 2.4 Embedded Screenshots

- [ ] Embed key frame images in markdown output: `![Slide: Architecture Diagram](frame_1230.png)`
- [ ] Embed in EPUB/HTML output as inline images
- [ ] Store frames in output directory alongside the article
- [ ] `--screenshot-dir` to control where frames are saved
- [ ] Smart captioning: auto-generate alt text from visual content

Effort: Hard. Frame extraction is easy. Vision model integration needs
careful prompt engineering. Code extraction from screenshots is an
active research area but commercial vision models handle it well.

---

## Phase 3 — Long Videos

**Why third:** Videos over 1 hour are the highest-value content
(podcasts, lectures, conference talks) but currently produce the worst
output because they overflow LLM context windows or get truncated.

**Success metric:** A 3-hour podcast produces an article as good as
a 15-minute video does today.

### 3.1 Context Window Management

- [ ] Know each model's context limit: Ollama (query `/api/show`), Claude (known per model), OpenAI (known per model)
- [ ] Count tokens before sending (tiktoken for OpenAI, estimate for others)
- [ ] When transcript fits: send as-is (current behavior)
- [ ] When transcript doesn't fit: auto-trigger chunked generation
- [ ] `--max-tokens` flag to override context detection

### 3.2 Chunked Generation

When the transcript exceeds the context window:

1. Split transcript at chapter boundaries (preferred) or topic boundaries
2. Generate a section summary for each chunk
3. Combine summaries into a coherent article with a synthesis pass
4. Preserve chapter headings and timestamp references across chunks

- [ ] Implement sliding-window chunking with overlap
- [ ] Chapter-boundary splitting (already exists, needs refinement)
- [ ] Topic-boundary detection for unchaptered videos (sentence similarity or paragraph-level heuristics)
- [ ] Synthesis pass that reads all chunk summaries and produces final article
- [ ] Show per-chunk progress: `generating [3/7]...`

### 3.3 Multi-Pass Generation

For the best quality on long content:

- [ ] `--depth deep` flag: outline pass → section pass → synthesis pass
- [ ] Pass 1: Generate structured outline from full transcript (or chunked summaries)
- [ ] Pass 2: Expand each outline section using relevant transcript chunks
- [ ] Pass 3: Edit pass for consistency, flow, and deduplication
- [ ] Default to single-pass for short videos, multi-pass for 60+ minutes

### 3.4 Cost Estimation & Budget Control

Long videos + multi-pass + cloud APIs = surprise bills. Users need to
know what they're about to spend before they spend it.

- [ ] `--estimate` flag: show token count and estimated cost, then exit (don't generate)
- [ ] Before generation on paid APIs: print estimated cost to stderr
- [ ] `--budget` flag: abort if estimated cost exceeds threshold
- [ ] Track cumulative spending in `~/.local/share/readtube/usage.json`
- [ ] `readtube usage` command: show total tokens/cost by backend and time period

```bash
$ readtube --estimate URL
Transcript: 45,230 tokens
Model: claude-sonnet-4-20250514 (200K context)
Strategy: single-pass
Estimated cost: ~$0.18 (input: $0.14, output: ~$0.04)

$ readtube --budget 0.50 URL  # abort if > $0.50
```

Effort: Hard. Chunking strategy and synthesis quality need careful tuning.
Cost estimation is straightforward but needs per-model pricing data.

---

## Phase 4 — Structured Data Extraction

**Why fourth:** Articles are for reading. But videos contain structured
information that's more useful as data than prose. Books mentioned,
people referenced, tools recommended, claims made, URLs shared. This
data powers search, cross-referencing, and integration with other tools.

**Success metric:** `readtube URL --extract entities` produces a JSON
file that a script can parse to build a reading list, a link collection,
or a knowledge graph.

### 4.1 Entity Extraction

- [ ] `--extract entities` mode: output structured JSON instead of prose
- [ ] Extract: people, organizations, books, papers, tools/software, URLs, dates, locations
- [ ] Each entity includes: name, context (why mentioned), timestamp, confidence
- [ ] Output as JSON for programmatic use, or markdown table for reading

```bash
$ readtube URL --extract entities --format json
{
  "people": [
    {"name": "Geoffrey Hinton", "context": "Pioneer of backpropagation", "timestamp": "4:32"},
    {"name": "Yann LeCun", "context": "Disagreed with Hinton on approach", "timestamp": "12:05"}
  ],
  "books": [
    {"title": "Deep Learning", "authors": ["Goodfellow", "Bengio", "Courville"], "context": "Recommended as starting point", "timestamp": "28:15"}
  ],
  "tools": [
    {"name": "PyTorch", "context": "Used for all demos in the talk", "timestamp": "8:20"}
  ]
}
```

### 4.2 Claim Extraction

- [ ] `--extract claims` mode: extract specific factual claims with timestamps
- [ ] Each claim: statement, evidence given, timestamp, speaker (if identified)
- [ ] Useful for fact-checking, study notes, debate analysis
- [ ] `--extract claims --verify` flag: ask LLM to flag claims that seem dubious

### 4.3 Reference Extraction

- [ ] `--extract references` mode: compile all books, papers, links, and resources mentioned
- [ ] Parse video description for links and timestamps
- [ ] Parse pinned comment for additional links (YouTube API)
- [ ] Output as bibliography (markdown), BibTeX, or JSON
- [ ] Deduplicate across description, transcript, and comments

### 4.4 Obsidian-Native Structured Output

- [ ] `--frontmatter` flag: YAML frontmatter with title, channel, date, URL, duration, tags, reading time
- [ ] Auto-generate tags from extracted entities and topics
- [ ] Dataview-compatible fields for Obsidian queries
- [ ] Wikilinks to extracted entities: `[[Geoffrey Hinton]]`, `[[Deep Learning (book)]]`
- [ ] Auto-name output files: `{Channel} - {Title}.md`

Effort: Medium. LLMs are good at entity extraction. The challenge is
consistent output format and integration with downstream tools.

---

## Phase 5 — Knowledge Workflow

**Why fifth:** Once content quality is high and structured data flows,
help users build a personal knowledge base. This is where the
accumulated value of 100+ processed videos becomes greater than the
sum of its parts.

**Success metric:** A user with 100+ articles can find any piece of
information in under 10 seconds.

### 5.1 Channel Feeds

- [ ] `readtube feed channels.txt` — fetch latest videos from channels, skip already-processed
- [ ] Track processed video IDs in a local state file
- [ ] `channels.txt` format: one handle or URL per line, `#` comments
- [ ] Concurrent processing: fetch and process N videos in parallel

```bash
# channels.txt
@3Blue1Brown
@AndrejKarpathy
@DwarkeshPatel

# Daily cron
0 8 * * * readtube feed ~/channels.txt -o ~/Obsidian/Videos/ --mode takeaways --frontmatter
```

### 5.2 Search

- [ ] `readtube search "backpropagation"` — full-text search across generated articles
- [ ] Index articles at generation time (SQLite FTS5, stored alongside cache)
- [ ] Return: matching filename, relevant snippet, source video link
- [ ] `--format json` for programmatic use
- [ ] Search across entity extractions too (find all videos that mention a person/book)

### 5.3 Cross-Video Q&A

- [ ] `readtube ask "What do Karpathy and 3B1B say differently about transformers?"`
- [ ] Find relevant articles via search index
- [ ] Stuff top-N relevant chunks into LLM context with source attribution
- [ ] Output answer with citations: `[Source: "How GPT Works" by Karpathy, 12:30]`
- [ ] `--sources` flag to show which articles were consulted

### 5.4 Topic Clustering

- [ ] `readtube topics` — analyze all processed articles and group by topic
- [ ] Show: topic name, video count, key speakers, timeline of coverage
- [ ] `readtube topics "machine learning"` — deep dive into one topic across all videos
- [ ] Generate topic summary that synthesizes insights from multiple sources

Effort: Medium-Hard. Search is straightforward. Q&A quality depends on
retrieval quality. Topic clustering needs embedding-based similarity.

---

## Phase 6 — Performance & Reliability

**Why sixth:** Once the feature set is rich, make it fast and robust.
A batch of 100 videos should be fire-and-forget overnight.

**Success metric:** Processing 100 videos overnight with zero failures
that require manual intervention.

### 6.1 Concurrent Processing

- [ ] Process N videos in parallel (default: 3, configurable with `--jobs N`)
- [ ] Respect rate limits per backend (YouTube, SponsorBlock, LLM API)
- [ ] Shared progress display: `[12/100] processing "How GPT Works"...`
- [ ] Fail gracefully: log failures, continue with remaining videos
- [ ] Resume interrupted batches: skip already-completed videos

### 6.2 Retry & Resilience

- [ ] Exponential backoff with jitter for all external calls (partially done)
- [ ] Circuit breaker: after N consecutive failures, pause and warn user
- [ ] `--retry N` flag to control max retries per video
- [ ] Separate retry strategies for transient (network, rate limit) vs permanent (video deleted) errors
- [ ] `readtube batch --resume` to pick up where a failed batch left off

### 6.3 Output Caching

- [ ] Cache generated articles (not just transcripts) by content hash
- [ ] Regenerate only when prompt template or model changes
- [ ] `--force` flag to bypass article cache
- [ ] Cache invalidation when readtube version changes prompt templates

### 6.4 Progress & Reporting

- [ ] Rich progress output on stderr: current step, ETA, token counts
- [ ] `--quiet` flag: suppress all progress, only output content
- [ ] `--json-progress` flag: machine-readable progress for integration with other tools
- [ ] Batch summary report: N processed, N failed, N skipped, total cost

Effort: Medium. Concurrency in Python (asyncio or ThreadPoolExecutor)
is well-understood. The challenge is graceful error handling at scale.

---

## Phase 7 — E-Reader Pipeline

**Why seventh:** E-readers are where long-form reading actually happens.
EPUB generation exists but the workflow has friction.

### 7.1 Send-to-Kindle

- [ ] `readtube URL --kindle` — generate EPUB, email to Kindle address
- [ ] `kindle_email` setting in config.toml
- [ ] SMTP config in config.toml (or use system `sendmail`)
- [ ] Batch: `readtube playlist URL --kindle` sends digest EPUB

### 7.2 EPUB Polish

- [ ] Test on real Kindle, Kobo, and Apple Books
- [ ] Improve cover image embedding (hi-res thumbnails)
- [ ] Better table of contents for multi-chapter articles
- [ ] `--theme` support for EPUB (already works for HTML)
- [ ] Custom CSS via config.toml
- [ ] Embed extracted screenshots in EPUB

### 7.3 Digest Mode

- [ ] `readtube digest channels.txt -o weekly.epub` — combine multiple articles into one EPUB
- [ ] Table of contents with all articles
- [ ] One email to Kindle, one book with the week's reading
- [ ] Include entity index at the back (all people, books, tools mentioned across articles)

---

## Phase 8 — Distribution

**Why eighth:** Build for yourself first, distribute when it's good.
Premature distribution means supporting broken features.

### 8.1 PyPI

- [ ] Publish `pip install readtube`
- [ ] Optional extras: `readtube[epub]`, `readtube[claude]`, `readtube[vision]`, `readtube[all]`
- [ ] GitHub Actions: test on push, publish on tag
- [ ] Proper README: install, quickstart, examples, config reference

### 8.2 Homebrew

- [ ] `brew install readtube`
- [ ] Tap or core formula
- [ ] Auto-update on release

### 8.3 Nix

- [ ] Update flake/shell.nix for new package structure
- [ ] Cachix for pre-built binaries

### 8.4 Docker

- [ ] `docker run readtube URL` — zero-install usage
- [ ] Pre-bundled with yt-dlp, ffmpeg, and optional dependencies
- [ ] Mount volume for config and cache persistence

---

## Phase 9 — Alternative Inputs

**Why last:** YouTube covers 90% of the use case. Expand only after
the core is excellent.

### 9.1 Local Video/Audio Files

- [ ] `readtube file.mp4` — transcribe with Whisper, then process normally
- [ ] `readtube file.mp3` — audio-only, same pipeline
- [ ] Whisper backend: local (whisper.cpp) or API (OpenAI Whisper)
- [ ] Cache transcriptions by file content hash

### 9.2 Podcasts

- [ ] `readtube podcast <rss-url>` — fetch latest episode, transcribe, generate
- [ ] Episode selection: `--latest`, `--episode N`, `--all`
- [ ] Speaker diarization for interview podcasts (via pyannote or simple heuristics)

### 9.3 Other Platforms

yt-dlp already supports 1000+ sites. Many will work out of the box.

- [ ] Test and document: Vimeo, Twitch VODs, Twitter/X spaces, Bilibili
- [ ] Platform-specific metadata extraction where needed
- [ ] Community-contributed platform support guides

### 9.4 Live Stream Archives

- [ ] Process YouTube live stream archives (they have auto-captions)
- [ ] Handle super-long durations (4-12 hours) via aggressive chunking
- [ ] Extract highlights: detect audience engagement spikes from chat replay timestamps

---

## Non-Goals

Deliberate decisions about what readtube will never be:

- **GUI / web app.** The CLI is the product. Obsidian, Kindle, and your
  browser are better reading apps than anything we'd build.
- **User accounts / cloud.** Local-first. Your filesystem is your database.
  No servers, no subscriptions, no data collection.
- **Real-time / streaming video.** We process finished content.
  Live transcription is a different problem.
- **Social features.** No sharing, feeds, or recommendations.
  Pipe the output to whatever you want.
- **Translation.** Use DeepL, Google Translate, or your LLM of choice.
  We produce the source text.
- **TTS.** Use Eleven Labs, macOS `say`, or your preferred tool.
  We produce text, you voice it.
- **Competing with Notion/Readwise/etc.** We're a generator, not a reader.
  We produce files that slot into YOUR existing workflow.
- **Perfect diarization.** We use heuristics for speaker ID, not ML
  models. Good enough for attribution, not for academic transcription.

---

## Principles

1. **Output quality over feature count.** One mode that produces excellent
   articles beats five modes that produce mediocre ones.
2. **Composable over integrated.** Pipe to grep, jq, Obsidian, Kindle,
   email, whatever. Don't build what the ecosystem already has.
3. **Local over cloud.** Ollama is the default. Cloud APIs are opt-in.
   Nothing leaves your machine unless you choose a cloud LLM.
4. **Fewer dependencies over more.** Core needs only yt-dlp and
   youtube-transcript-api. Everything else is optional.
5. **Transparent over magic.** Show what's happening. Cache hits,
   backend selection, token counts, progress — all visible on stderr.
6. **Data over prose.** Articles are the default, but structured data
   (entities, claims, references) is often more useful. Support both.
7. **Fail gracefully, recover automatically.** Network errors, rate limits,
   and API failures should never lose work or require user intervention
   in batch mode.
