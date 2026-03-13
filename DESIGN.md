# Readtube CLI — Design Spec

## Philosophy

One command. YouTube videos in, readable articles out. Unix pipeline friendly.
No GUI, no web app, no daemon. Generate content, read it wherever you want.

## Command Interface

```
readtube <url>                          # article → stdout (markdown)
readtube <url> -o article.md            # article → file
readtube <url> -o article.epub          # format detected from extension
readtube <url> -o article.pdf           # requires weasyprint
readtube <url> -o article.html          # standalone HTML with embedded CSS

readtube <url> --mode tldr              # 3-5 bullet points
readtube <url> --mode takeaways         # structured key points
readtube <url> --mode article           # full article (default)
readtube <url> --mode transcript        # cleaned transcript, no LLM needed

readtube <url> --timestamps             # keep [MM:SS] markers linked to video
readtube <url> --chapters               # split output by video chapters
readtube <url> --lang es                # prefer Spanish transcript

readtube <url> --backend ollama         # override LLM backend
readtube <url> --model llama3           # override model

readtube playlist <url>                 # process all videos, one file each
readtube playlist <url> -o ./articles/  # output dir for playlist
readtube playlist <url> --max 10        # limit to N videos

readtube batch urls.txt                 # one URL per line
readtube batch urls.txt -o ./out/       # output directory

readtube config                         # print current config
readtube config --init                  # create default config file
readtube cache clear                    # wipe transcript cache
readtube cache stats                    # show cache size and entries
```

## Output Behavior

Stdout is for content. Stderr is for progress.

```
$ readtube https://youtube.com/watch?v=dQw4w9WgXcQ
# Never Gonna Give You Up — Rick Astley

Rick Astley's iconic 1987 hit...
(full article to stdout)
```

```
$ readtube https://youtube.com/watch?v=dQw4w9WgXcQ -o article.epub
fetching video info...
downloading transcript...
generating article (claude/claude-sonnet-4-20250514)...
rendering epub...
saved: article.epub (42 KB)
```

When writing to a file, progress goes to stderr. When writing to stdout, progress
is suppressed (clean pipe). Use `--verbose` to force progress to stderr even when
piping.

```
$ readtube URL | head -20                    # silent, just content
$ readtube URL --verbose 2>/dev/null         # content + progress separated
$ readtube URL -o out.md 2>&1 | tee log     # capture everything
```

## Exit Codes

```
0  success
1  general error
2  invalid arguments
3  video not found / unavailable
4  transcript not available
5  LLM error (backend unreachable, rate limit, etc.)
6  output format error (missing weasyprint, etc.)
```

## Configuration

```toml
# ~/.config/readtube/config.toml

[llm]
backend = "claude"                  # ollama | claude | openai
model = "claude-sonnet-4-20250514"
api_key_env = "ANTHROPIC_API_KEY"   # name of env var, never the key itself

# [llm]
# backend = "ollama"
# model = "llama3"
# url = "http://localhost:11434"

# [llm]
# backend = "openai"
# model = "gpt-4o"
# api_key_env = "OPENAI_API_KEY"
# url = "https://api.openai.com/v1"  # or any compatible endpoint

[output]
default_format = "md"               # md | epub | pdf | html
default_mode = "article"            # article | tldr | takeaways | transcript
timestamps = false                  # include [MM:SS] markers
chapters = true                     # split by chapters when available

[cache]
dir = "~/.cache/readtube"           # transcript cache location
ttl_days = 30                       # cache expiration
```

Precedence: CLI flags > environment variables > config file > defaults.

No config file needed to start. Sensible defaults work out of the box with
`--backend ollama` or `ANTHROPIC_API_KEY` in environment.

## Config Resolution for LLM

1. If `--backend` flag is passed, use it
2. If `READTUBE_BACKEND` env var is set, use it
3. If config.toml has `[llm].backend`, use it
4. Auto-detect: check if Ollama is running locally, use it
5. If `ANTHROPIC_API_KEY` is set, use Claude
6. If `OPENAI_API_KEY` is set, use OpenAI
7. Error: "No LLM backend configured. Run `readtube config --init`"

## Transcript Mode (No LLM Needed)

```
$ readtube URL --mode transcript
```

This skips LLM entirely. Fetches the transcript, cleans it up, outputs it.
Useful for piping into other tools or reading raw transcripts. This works
with zero configuration — no API keys, no Ollama, nothing.

```
$ readtube URL --mode transcript | wc -w        # word count
$ readtube URL --mode transcript > raw.txt       # save for later
$ readtube URL --mode transcript | llm "summarize this"  # pipe to another LLM tool
```

## Timestamps

When `--timestamps` is used, the article includes markers that link back
to the video:

```markdown
# How Neural Networks Learn

Neural networks learn through backpropagation [4:32](https://youtube.com/watch?v=xxx&t=272),
adjusting weights layer by layer. The key insight is that...

The training process [12:15](https://youtube.com/watch?v=xxx&t=735) involves
feeding thousands of examples...
```

Implementation: transcript segments already have timestamps. Include them as
context in the LLM prompt with instructions to preserve `[MM:SS]` markers at
key topic transitions. Post-process markers into markdown links.

## Chapter-Aware Output

When `--chapters` is used and the video has chapters:

```markdown
# Video Title

## Introduction [0:00](...)

Opening content...

## How It Works [3:45](...)

Technical explanation...

## Conclusion [28:30](...)

Closing thoughts...
```

The transcript is split by chapter boundaries before being sent to the LLM.
Each chapter can be processed independently (better for long videos that
exceed context windows).

## Playlist & Batch Processing

```
$ readtube playlist "https://youtube.com/playlist?list=PLxxx" -o ./articles/
processing 12 videos...
 [1/12] How Neural Networks Learn... done (article.md)
 [2/12] Transformers Explained... done (article.md)
 [3/12] The Future of AI... generating...
```

Output files are named: `{channel} - {title}.{ext}` (sanitized for filesystem).

Batch mode reads a plain text file, one URL per line:

```
$ cat urls.txt
https://youtube.com/watch?v=abc
https://youtube.com/watch?v=def
https://youtube.com/watch?v=ghi

$ readtube batch urls.txt -o ./out/
```

Lines starting with `#` are comments. Empty lines are skipped.

## Caching

Transcripts are cached locally to avoid re-fetching from YouTube.

```
~/.cache/readtube/
├── transcripts/
│   ├── dQw4w9WgXcQ.json     # cached transcript
│   └── abc123.json
└── metadata/
    ├── dQw4w9WgXcQ.json     # cached video info
    └── abc123.json
```

Cache is keyed by video ID. Changing `--lang` busts the transcript cache
(different language = different cache entry, keyed as `{video_id}_{lang}`).

Generated articles are NOT cached — they depend on the LLM, model, mode, and
prompt, so caching would be misleading. If you want to keep an article, save
it to a file.

## LLM Prompts

Three prompt templates, one per mode:

### article (default)
```
You are a skilled writer who transforms video transcripts into well-structured,
readable articles. Write in a clear, engaging style. Preserve the speaker's key
ideas, arguments, and examples. Use markdown formatting with headers, paragraphs,
and occasional lists where appropriate.

{chapter_context}
{timestamp_instructions}

Transcript:
{transcript}
```

### tldr
```
Summarize this video transcript in 3-5 concise bullet points. Each bullet should
capture one key idea. No fluff, no filler.

Transcript:
{transcript}
```

### takeaways
```
Extract the key takeaways from this video transcript as a structured list.
Group related points under topic headers. Include specific claims, data points,
and actionable insights. Skip small talk and filler.

Transcript:
{transcript}
```

## Streaming

When writing to a file with a configured LLM, the article streams to disk
and progress updates on stderr:

```
$ readtube URL -o article.md
fetching video info... done
downloading transcript... done (4,832 words)
generating article (claude/claude-sonnet-4-20250514)...
  ██████████░░░░░░░░░░ 52% (streaming)
rendering... done
saved: article.md (12 KB, ~4 min read)
```

When writing to stdout, the article streams directly — you see it being
written in real time (if your terminal supports it and output is a TTY).

## Error Messages

Errors are human-readable, printed to stderr, with actionable suggestions:

```
$ readtube https://youtube.com/watch?v=private123
error: video not found or is private

$ readtube URL
error: no LLM backend configured
  → set ANTHROPIC_API_KEY, or run: readtube config --init

$ readtube URL --backend ollama
error: cannot connect to Ollama at http://localhost:11434
  → is Ollama running? try: ollama serve

$ readtube URL -o article.pdf
error: PDF output requires weasyprint
  → install: pip install readtube[pdf]
```

## What We Keep From Current Codebase

- `videos.py` — video metadata via yt-dlp (clean it up, keep core)
- `transcripts.py` — transcript fetching (keep, simplify caching)
- `llm.py` — LLM backends (keep all 4, improve auto-detection)
- `ebook.py` — EPUB/PDF generation (keep, it's solid)
- `chapters.py` — chapter splitting (keep)
- `errors.py` — error types and retry logic (keep, good design)
- `cache.py` — SQLite cache (simplify to filesystem JSON)
- `config.py` — config types (rewrite for TOML)
- `themes.py` — CSS for HTML/EPUB output (keep)

## What We Drop

- `web/` — entire web application (not our job anymore)
- `tts.py` — text to speech (scope creep, use external tools)
- `translate.py` — translation (scope creep, use external tools)
- `diarization.py` — speaker detection (fold simple version into transcripts.py)
- `images.py` — frame extraction (cover thumbnails stay in ebook.py)
- `rss.py` — RSS generation (not needed without web app)
- `scheduler.py` — scheduling (use cron)
- `integrations.py` — Readwise etc. (pipe output to their CLI tools instead)
- `async_fetch.py` — async fetcher (simplify with regular asyncio in batch)
- `batch.py` — YAML batch config (replaced by simple `batch` subcommand with text file)
- `macos/` — entire Swift macOS application

## What We Add

- TOML config support
- `--mode tldr` and `--mode takeaways` prompt templates
- `--timestamps` with video-linked markers
- Streaming LLM output to terminal
- Better progress reporting on stderr
- `readtube config --init` scaffolding
- Proper exit codes
- `--verbose` / `--quiet` flags

## Project Structure (After Redesign)

```
readtube/
├── readtube/
│   ├── __init__.py
│   ├── __main__.py          # entry point
│   ├── cli.py               # argument parsing (argparse or click)
│   ├── pipeline.py          # orchestrator: fetch → transcribe → generate → render
│   ├── video.py             # yt-dlp wrapper (metadata + subtitles)
│   ├── transcript.py        # transcript fetching + cleaning
│   ├── llm.py               # LLM backends (ollama, claude, openai)
│   ├── render.py            # output rendering (markdown, epub, pdf, html)
│   ├── chapters.py          # chapter detection + splitting
│   ├── cache.py             # filesystem transcript cache
│   ├── config.py            # TOML config loading + CLI flag merging
│   ├── errors.py            # error types + retry logic
│   ├── prompts.py           # prompt templates per mode
│   └── themes.py            # CSS themes for HTML/EPUB
├── tests/
│   ├── test_pipeline.py
│   ├── test_video.py
│   ├── test_transcript.py
│   ├── test_llm.py
│   ├── test_render.py
│   ├── test_chapters.py
│   ├── test_config.py
│   └── test_cli.py
├── pyproject.toml
├── README.md
└── LICENSE
```

13 source files. That's it. No web app, no TTS, no translation, no scheduler,
no RSS, no async fetcher, no batch YAML parser, no Readwise integration, no
macOS app, no Docker, no Tailwind, no Jinja templates.

## Dependencies

### Required
- `yt-dlp` — video metadata and subtitles
- `youtube-transcript-api` — transcript fetching (fallback)
- `tomli` — TOML parsing (stdlib in 3.11+)

### Optional (per output format)
- `ebooklib` — EPUB generation (`pip install readtube[epub]`)
- `weasyprint` — PDF generation (`pip install readtube[pdf]`)
- `markdown` — HTML rendering (`pip install readtube[html]`)

### Optional (per LLM backend)
- `anthropic` — Claude API (`pip install readtube[claude]`)
- `openai` — OpenAI API (`pip install readtube[openai]`)
- `llama-cpp-python` — local models (`pip install readtube[local]`)
- (Ollama needs no Python dependency — it's just HTTP)

### Development
- `pytest`
- `pytest-cov`

## Install

```bash
# Minimal (ollama + markdown output only)
pip install readtube

# With Claude + EPUB
pip install readtube[claude,epub]

# Everything
pip install readtube[all]

# Or with nix
nix-shell
```

## Examples

```bash
# Quick summary of a talk
readtube https://youtube.com/watch?v=abc --mode tldr

# Full article saved as EPUB for Kindle
readtube https://youtube.com/watch?v=abc -o talk.epub

# Process a conference playlist, save to Obsidian
readtube playlist "https://youtube.com/playlist?list=PLxxx" \
  -o ~/Obsidian/Conferences/

# Get transcript for further processing
readtube https://youtube.com/watch?v=abc --mode transcript \
  | llm "extract all mentioned paper titles"

# Batch process your watch-later list
readtube batch watch-later.txt -o ~/articles/ --mode takeaways

# Override backend for one run
ANTHROPIC_API_KEY=sk-xxx readtube URL --backend claude --model claude-sonnet-4-20250514
```
