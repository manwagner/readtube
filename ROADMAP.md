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

### 1.3 Genre-Aware Prompts

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

### 1.4 Prompt Evaluation Framework

Prompts can't be improved without measurement.

- [ ] Curate 50+ test videos: 8-10 per genre, ranging from 5 min to 2+ hours
- [ ] Build `readtube eval` command that runs all test videos and saves outputs
- [ ] Score rubric: accuracy (are facts correct?), readability (would you read this?), structure (headings/flow make sense?), completeness (key points covered?)
- [ ] Track scores over time as prompts are iterated
- [ ] Document which models produce best results per genre

Effort: Medium. The framework is simple. The iteration is ongoing.

---

## Phase 2 — Long Videos

**Why second:** Videos over 1 hour are the highest-value content
(podcasts, lectures, conference talks) but currently produce the worst
output because they overflow LLM context windows or get truncated.

**Success metric:** A 3-hour podcast produces an article as good as
a 15-minute video does today.

### 2.1 Context Window Management

- [ ] Know each model's context limit: Ollama (query `/api/show`), Claude (known per model), OpenAI (known per model)
- [ ] Count tokens before sending (tiktoken for OpenAI, estimate for others)
- [ ] When transcript fits: send as-is (current behavior)
- [ ] When transcript doesn't fit: auto-trigger chunked generation
- [ ] `--max-tokens` flag to override context detection

### 2.2 Chunked Generation

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

### 2.3 Multi-Pass Generation

For the best quality on long content:

- [ ] `--depth deep` flag: outline pass → section pass → synthesis pass
- [ ] Pass 1: Generate structured outline from full transcript (or chunked summaries)
- [ ] Pass 2: Expand each outline section using relevant transcript chunks
- [ ] Pass 3: Edit pass for consistency, flow, and deduplication
- [ ] Default to single-pass for short videos, multi-pass for 60+ minutes

Effort: Hard. This is the most complex feature. Chunking strategy and
synthesis quality need careful tuning.

---

## Phase 3 — Knowledge Workflow

**Why third:** Once content quality is high and long videos work, users
will accumulate articles. Help them build a personal knowledge base.

**Success metric:** A user with 100+ articles can find any piece of
information in under 10 seconds.

### 3.1 Obsidian Integration

- [ ] `--frontmatter` flag: YAML frontmatter with title, channel, date, URL, duration, tags, reading time
- [ ] Auto-generate tags from article content (ask LLM for 3-5 topic tags)
- [ ] Embed thumbnail as markdown image
- [ ] `--template` flag for custom Jinja-style output templates
- [ ] Auto-name output files: `{Channel} - {Title}.md`
- [ ] Skip already-generated files in output directory

Example output:

```markdown
---
title: "How Neural Networks Learn"
channel: "3Blue1Brown"
date: 2024-03-15
url: https://youtube.com/watch?v=abc
duration: 1245
tags: [neural-networks, machine-learning, backpropagation]
reading_time: 8 min
---

# How Neural Networks Learn

Neural networks learn through backpropagation [4:32](...)...
```

### 3.2 Channel Feeds

- [ ] `readtube feed channels.txt` — fetch latest videos from channels, skip already-processed
- [ ] Track processed video IDs in a local state file
- [ ] `channels.txt` format: one handle or URL per line, `#` comments

```bash
# channels.txt
@3Blue1Brown
@AndrejKarpathy
@DwarkeshPatel

# Daily cron
0 8 * * * readtube feed ~/channels.txt -o ~/Obsidian/Videos/ --mode takeaways --frontmatter
```

### 3.3 Search

- [ ] `readtube search "backpropagation"` — full-text search across generated articles
- [ ] Index articles at generation time (SQLite FTS5, stored alongside cache)
- [ ] Return: matching filename, relevant snippet, source video link
- [ ] `--format json` for programmatic use

### 3.4 Cross-Video Q&A

- [ ] `readtube ask "What do Karpathy and 3B1B say differently about transformers?"`
- [ ] Find relevant articles via search index
- [ ] Stuff top-N relevant chunks into LLM context with source attribution
- [ ] Output answer with citations: `[Source: "How GPT Works" by Karpathy, 12:30]`

Effort: Medium-Hard. Search is straightforward. Q&A quality depends on
retrieval quality.

---

## Phase 4 — E-Reader Pipeline

**Why fourth:** E-readers are where long-form reading actually happens.
EPUB generation exists but the workflow has friction.

### 4.1 Send-to-Kindle

- [ ] `readtube URL --kindle` — generate EPUB, email to Kindle address
- [ ] `kindle_email` setting in config.toml
- [ ] SMTP config in config.toml (or use system `sendmail`)
- [ ] Batch: `readtube playlist URL --kindle` sends digest EPUB

### 4.2 EPUB Polish

- [ ] Test on real Kindle, Kobo, and Apple Books
- [ ] Improve cover image embedding (hi-res thumbnails)
- [ ] Better table of contents for multi-chapter articles
- [ ] `--theme` support for EPUB (already works for HTML)
- [ ] Custom CSS via config.toml

### 4.3 Digest Mode

- [ ] `readtube digest channels.txt -o weekly.epub` — combine multiple articles into one EPUB
- [ ] Table of contents with all articles
- [ ] One email to Kindle, one book with the week's reading

---

## Phase 5 — Distribution

**Why fifth:** Build for yourself first, distribute when it's good.
Premature distribution means supporting broken features.

### 5.1 PyPI

- [ ] Publish `pip install readtube`
- [ ] Optional extras: `readtube[epub]`, `readtube[claude]`, `readtube[all]`
- [ ] GitHub Actions: test on push, publish on tag
- [ ] Proper README: install, quickstart, examples, config reference

### 5.2 Homebrew

- [ ] `brew install readtube`
- [ ] Tap or core formula
- [ ] Auto-update on release

### 5.3 Nix

- [ ] Update flake/shell.nix for new package structure
- [ ] Cachix for pre-built binaries

---

## Phase 6 — Alternative Inputs

**Why last:** YouTube covers 90% of the use case. Expand only after
the core is excellent.

### 6.1 Local Video/Audio Files

- [ ] `readtube file.mp4` — transcribe with Whisper, then process normally
- [ ] `readtube file.mp3` — audio-only, same pipeline
- [ ] Whisper backend: local (whisper.cpp) or API (OpenAI Whisper)
- [ ] Cache transcriptions by file content hash

### 6.2 Podcasts

- [ ] `readtube podcast <rss-url>` — fetch latest episode, transcribe, generate
- [ ] Episode selection: `--latest`, `--episode N`, `--all`
- [ ] Speaker diarization for interview podcasts (via pyannote or simple heuristics)

### 6.3 Other Platforms

yt-dlp already supports 1000+ sites. Many will work out of the box.

- [ ] Test and document: Vimeo, Twitch VODs, Twitter/X spaces, Bilibili
- [ ] Platform-specific metadata extraction where needed
- [ ] Community-contributed platform support guides

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
