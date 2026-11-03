# xhs-video-agent

**English** | [中文版](README.zh-CN.md)

**Turn an article into a publishable 3:4 Xiaohongshu short video: research → narration script → web presentation → voice-over → screen recording → three gates → publish → T+3 day retro.**

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-0078d4.svg)](#11-known-limitations)
[![Node](https://img.shields.io/badge/node-%3E%3D18-brightgreen.svg)](#41-prerequisites)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for the fork/PR workflow, local verification commands, and the long-lived `feature` branch.

---

## Table of Contents

- [1. What This Is](#1-what-this-is)
- [2. Sample Output](#2-sample-output)
- [3. Workflow Overview](#3-workflow-overview)
- [4. Quick Start](#4-quick-start)
- [5. The Cheat Calibration Loop](#5-the-cheat-calibration-loop)
- [6. The Three Gates](#6-the-three-gates)
- [7. Optional: Unattended Heartbeat](#7-optional-unattended-heartbeat)
- [8. Repository Layout](#8-repository-layout)
- [9. Example Walkthrough](#9-example-walkthrough)
- [10. FAQ](#10-faq)
- [11. Known Limitations](#11-known-limitations)
- [12. Dependencies & Credits](#12-dependencies--credits)
- [13. License](#13-license)

---

## 1. What This Is

This is a **video production pipeline built for an AI agent**: the agent researches, writes the script, builds the web page, generates the voice-over, and records the screen. Scripts do the mechanical validation. The human only makes decisions at three hard checkpoints.

It is not "one-click AI video generation." Its core idea is **turning an uncontrollable creative process into a controlled set of steps** — every step has an artifact, a contract, and a gate.

### Who it is for

- People making knowledge, explainer, or product-breakdown short videos who want **reliable output** instead of luck
- People already using an agent that supports skills (Claude Code, CodeBuddy, Trae, etc.) and are willing to let the agent write code, not just copy
- People who accept a slow flow — write the script first, score it, then publish — in exchange for something that can be reviewed and iterated
- Windows users (the current scripts are PowerShell + Chrome)

### Who it is not for

- People who want a "type a title, get a finished video" tool
- People doing pure talking-head videos with no web animation (the visuals here are web pages, not edited footage)
- People who do not want to touch a command line, Python, or Node
- People who need a turnkey SaaS (there is no server and no account system here)

---

## 2. Sample Output

The sample video *"Why does AI answer the same question differently every time?"* runs 2:33, with 13 beats at 1080×1440 portrait. The five images below are frames extracted from the final video (not design mockups):

| 0.6s · Hook: three different answers | 12s · Sampling = rolling dice |
|---|---|
| <img src="examples/shots/01-hook.png" width="320" alt="First frame: three different answers to the same question"> | <img src="examples/shots/02-sampling.png" width="320" alt="Sampling metaphor: circular arrows and dice"> |

| 30s · Probability table for the next token | 80s · top-p: keep only 90% |
|---|---|
| <img src="examples/shots/03-probability.png" width="320" alt="Bar chart of next-token probabilities"> | <img src="examples/shots/04-top-p.png" width="320" alt="top-p truncation illustration"> |

| 150s · Ending pays off the hook |
|---|
| <img src="examples/shots/05-ending.png" width="320" alt="Ending: the choice is yours"> |

> **The first frame is the cover.** Since 2026-10-27 this flow no longer produces a separate cover image — the platform uses the first frame as the cover in the feed. That means beat 1 must carry a large title, the hook, and one immediately understandable piece of information, rather than "welcome to my channel." The cover renderer in `tools/cover/` is still available if needed, but it is not part of the default delivery checklist.

The full set of sample text assets (research card / design intent / narration script / shot outline / self-check) lives in [`examples/ep11-sampling/`](examples/ep11-sampling/); see [`examples/README.md`](examples/README.md) for a per-file walkthrough.

---

## 3. Workflow Overview

```
Phase 0  Research     article.md + multiple public sources  →  facts.md (sources + key data + visual metaphors + teaching design)
   │                  ▲ Gate: check.ps1 -Gate pre-script (no script until facts are final)
Phase 1  Script       facts.md → script.md (narration) + outline.md (shot outline) + beats.json
   │                  + design-intent.md (three pre-writing questions) + script-selfcheck.md (four-layer self-check)
   │                  ▲ Gate: check.ps1 -Gate pre-code (beat count / opening three elements / duration estimate)
   │                  ▲ Checkpoint 1: the human aligns on 6 things at once (research card / script / outline / theme / assets / build mode)
Phase 2  Web build    scaffold → 3:4 Vite + React pages, built chapter by chapter (chapter 1 must pass human review)
   │                  ▲ Checkpoint 2: chapter 1 visual / pacing / AI-flavor review
Phase 3  Audio        extract-narrations → batch edge-tts synthesis → public/audio/
   │                  ▲ Checkpoint 3: whether to synthesize audio
   │                  ▲ Gate: check.ps1 -Gate pre-render (count conservation + non-empty audio)
Phase 4  Recording    ?auto=1 one-take → raw-vertical/video.webm + marks.json
   │                  → build_master.py places audio at measured switch times → final mp4
   │                  → verify_sync.py cross-correlation A/V sync check
   │                  ▲ Gate: check.ps1 -Gate delivery
   │                  ▲ Visual review: shots-review.ps1 extracts one frame per beat
Phase 5  Publish gate validate.ps1 (9 compliance checks) + human confirmation
Phase 6  Publish      xiaohongshu-mcp publish_with_video (write operation, human must confirm)
Phase 7  Retro        T+3d pull.ps1 fetches metrics → prediction vs actual → one-line lesson written back to docs/LESSONS.md
```

Four "external memory" files decide the quality of the whole chain. **Do not skip them:**

| File | Purpose | Who writes it |
|---|---|---|
| `facts.md` | Source list, key numbers with citations, abstract concept → visual metaphor, teaching design, argument chain | Research phase, agent + human confirmation |
| `script.md` | Narration script, beats separated by `---`; one beat = one screen = one audio file | Phase 1, agent writes + human edits |
| `outline.md` | Chapters / beat count / visual element per step / transitions / reading-protection duration | Phase 1, agent writes + human confirms |
| `beats.json` | Millisecond beat table (step_id / chapter / start_ms / dur_ms / text) | Generated after the script is final; `marks.json` wins after recording |

**Single source of truth**: the array length in each chapter's `src/chapters/*/narrations.ts` = the number of steps in that chapter = the number of audio files. If you change the step count, you must bump `STORAGE_KEY` in `src/hooks/useStepper.ts`, or the browser-remembered cursor will be misaligned (see [docs/WORKFLOW.md](docs/WORKFLOW.md) §3).

---

## 4. Quick Start

The following assumes a clean Windows 10/11 machine and walks you through producing your first portrait video from scratch.

### 4.1 Prerequisites

| Component | Requirement | Check command |
|---|---|---|
| OS | Windows 10/11 (PowerShell 5.1) | `$PSVersionTable.PSVersion` |
| Node.js | ≥ 18, **native Windows build**, not the node inside WSL | `node -v` / `npm -v` |
| Python | ≥ 3.10 | `python --version` |
| Git for Windows | Needed for the bundled **Git Bash** to run `scaffold.sh` | `git --version` / `bash --version` |
| Google Chrome | Playwright drives your local Chrome directly (no Chromium download) | `"C:\Program Files\Google\Chrome\Application\chrome.exe"` exists |
| ffmpeg | Install separately, or use `@ffmpeg-installer` under `tools/record` | `ffmpeg -version` |
| edge-tts | Free TTS, no API key | `pip install edge-tts` → `edge-tts --version` |
| Agent | A skill-capable CLI (Claude Code / CodeBuddy / Trae, etc.) | Can read this repo's skill directory |

> **You must use Git Bash.** Typing `bash` directly on Windows may land in WSL (`C:\Windows\system32\bash.exe`), which is extremely slow on mounted drives and uses a different node environment. After installing Git for Windows, open "Git Bash" from the Start menu.

### 4.2 Install the third-party skills

This repository **does not copy** third-party skill source code — it only depends on them. Install them under `skills/` at the repo root, in this order (keep the directory names exactly as listed, because scripts and docs refer to them):

| Directory | Upstream | Purpose |
|---|---|---|
| `skills/web-video-presentation/` | <https://github.com/ConardLi/garden-skills> | Turns the narration script into a recordable Vite + React page |
| `skills/cheat-on-content/` | <https://github.com/XBuilderLAB/cheat-on-content> | Scoring / blind prediction / T+3 day retro |
| `skills/redbook-creator-publish/` | <https://lobehub.com/skills/rov639-skillhub-redbook-creator-publish> | Image-post publishing package (optional) |
| `skills/atutun-xhs-cover/` | <https://github.com/panggungunvibe/atutun-xhs-cover> | Atutun-style cover prompts (optional, off by default) |

The publishing path also needs **xiaohongshu-mcp**: <https://github.com/xpzouying/xiaohongshu-mcp>. Follow its README to place it under `mcp/`. Login state files (`cookies.json`, etc.) are already in `.gitignore`.

After installing, **fully quit and restart your agent client** (including any tray process), or the new skills will not be picked up.

### 4.3 Clone and install dependencies

```powershell
git clone https://github.com/<your-name>/xhs-video-agent.git
cd xhs-video-agent

# Playwright driver + ffmpeg installer
npm install --prefix tools/record

# Backend metrics scraper (optional, used during retro)
npm install --prefix tools/metrics

# Free TTS
pip install edge-tts

# Confirm the Chrome path (only needed if Chrome is not in the default location)
$env:CHROME_PATH = "D:\Program Files\Google\Chrome\Application\chrome.exe"
```

### 4.4 Initialize your account profile

`account.md` and `log.md` are private local files (already gitignored). Copy them from the templates:

```powershell
Copy-Item templates\account.md .\account.md
Copy-Item templates\log.md .\log.md
```

Open `account.md` and fill in the persona, audience, topic boundaries, and red lines. **It is the single source of truth for all content** — the agent must read it before starting any work.

### 4.5 Produce your first video

```powershell
# 1) Create an episode directory and copy the five skeletons into it
New-Item -ItemType Directory -Force videos\ep01 | Out-Null
Copy-Item templates\episode\*.md videos\ep01\

# 2) Put the source article into the project
#    videos\ep01\article.md
```

Then hand it to the agent and say three things in order (each maps to one gate):

**① Research and script**

> Read Phase 0 / Phase 1 of `docs/WORKFLOW.md`, use `videos/ep01/article.md` for a 3:4 portrait episode, and produce `facts.md` first. After I confirm it, write `script.md` + `outline.md` + `beats.json` + `design-intent.md` + `script-selfcheck.md`.

```powershell
# After facts.md is final
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 -ProjectDir videos\ep01 -Gate pre-script

# After the script trio + self-check are done
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 -ProjectDir videos\ep01 -Gate pre-code
```

**② Build the web page**

```bash
# Run in Git Bash; the target directory must not exist or must be empty
cd videos/ep01
bash ../../skills/web-video-presentation/scripts/scaffold.sh ./presentation-vertical --theme=blueprint
```

> Upstream `web-video-presentation` only supports 16:9 natively. For Xiaohongshu 3:4 you first need to apply the four-item local patch in [docs/VIDEO-GUIDE.md](docs/VIDEO-GUIDE.md) §3.2 (add `templates/src/stage.config.ts`, add a `--ratio` argument to `scaffold.sh`). This is **the only place you have to modify an upstream skill**; everything else lives in this repo. If you do not want to patch it yet, you can run the whole flow in 16:9 — Xiaohongshu will letterbox it.

**③ Voice-over and final cut**

```bash
cd videos/ep01/presentation-vertical
npm run dev -- --port 5175          # keep this terminal open
```

Open another Git Bash:

```bash
cd videos/ep01/presentation-vertical
npm run extract-narrations
# Copy the edge-tts snippet from skills/web-video-presentation/templates/scripts/tts-providers/README.md
# into scripts/tts-providers/edge-tts.sh
PRESENTATION_TTS=edge-tts PRESENTATION_TTS_VOICE=zh-CN-YunxiNeural npm run synthesize-audio
```

Open another PowerShell (do not close the dev server):

```powershell
$env:VARIANT = "vertical"
$env:VIDEO_PROJECT = "videos\ep01"

node tools\record\record.mjs                 # headless recording, presses Space itself
python tools\record\build_master.py videos\ep01   # place audio → videos\ep01\ep01-vertical.mp4
python tools\record\verify_sync.py videos\ep01    # A/V sync verification
```

Outputs:

```
videos\ep01\
├── raw-vertical\video.webm      # silent screen recording
├── raw-vertical\marks.json      # real switch time of each beat (the only basis for audio alignment)
└── ep01-vertical.mp4            # final cut with audio (1080×1440)
```

### 4.6 Pass the gates and publish

```powershell
# Process contract + count conservation + timeline
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 -ProjectDir videos\ep01 -Gate delivery

# Per-beat frame extraction for human review (the human owns semantics)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\shots-review.ps1 -ProjectDir videos\ep01

# Publish compliance (9 checks; needs .cheat-state.json and a prediction file)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate\validate.ps1 `
  -Title "Why does AI answer the same question differently every time?" `
  -TagsCount 5 `
  -VideoPath "videos\ep01\ep01-vertical.mp4" `
  -PredictionPath "predictions\ep01.md"
```

Once everything exits 0, publish through xiaohongshu-mcp's `publish_with_video`. **This is a write operation, so a human must click the final confirmation** — both the skill and the MCP enforce this.

### 4.7 After publishing

```powershell
node tools\metrics\login.js          # first run scans a QR code, creates tools\metrics\session.json
powershell -File tools\metrics\pull.ps1   # → data\metrics\latest.json
```

On T+3 days, compare the actual numbers with the blind prediction you wrote before publishing, and append one line of lesson to `docs/LESSONS.md`. See [docs/CHEAT-WORKFLOW.md](docs/CHEAT-WORKFLOW.md) for details.

---

## 5. The Cheat Calibration Loop

What really separates this flow from "just ask AI to write something" is that it **makes you place a bet before writing and review it afterwards**. Three phases:

| When | Action | Artifact |
|---|---|---|
| **Before writing** | Read the current rubric + the last video's numbers + recent lessons, then answer three questions: which metric am I moving / which episode is my reference / which lesson am I avoiding | `design-intent.md` |
| **While writing** | Self-score on five dimensions, citing exact lines from the script as evidence; any dimension ≤2 must be changed or explicitly justified; then do a one-sentence retelling | the `## cheat view` section of `script-selfcheck.md` |
| **After writing (T+3d)** | Compare prediction with actual, judge which dimension was right and which was wrong, compress into one line + one action for the next video | append one line to `docs/LESSONS.md` |

### Five-dimension formula (v1-retention)

```
score = HO×2 + PE×2 + TK×1.5 + NA×1 + QL×0.5
```

- **HO** Hook: can the first 3 seconds stop someone from scrolling
- **PE** Payoff: does the viewer get something actionable
- **TK** Takeaway: can it be retold in one sentence
- **NA** Narrative: is the story coherent, with no jumps
- **QL** Quality: baseline quality of facts, wording, and pacing

The objective function is not impressions — it is **average watch seconds per viewer**. Full definitions, anchor sentences, and scoring discipline are in [`docs/RUBRIC.md`](docs/RUBRIC.md).

### Three non-negotiable principles

1. **A prediction is locked once written**: `prediction_hashes` hash-locks it. Editing a prediction before publishing destroys your calibration sample. `validate.ps1` verifies the hash and blocks publishing on a mismatch.
2. **Blind prediction**: predictions must be written before you see any numbers; if you have already seen similar data, mark them explicitly as "contaminated".
3. **One-line lesson**: retros only record executable actions ("give the action before the name for every term"), never conclusions like "the numbers were bad this time."

---

## 6. The Three Gates

| Gate | What it governs | Command | Exit codes |
|---|---|---|---|
| `check.ps1` | **Process contract**: is the previous step final, is the beat count conserved, is audio complete, does the timeline cover every beat | `tools\pipeline\check.ps1 -ProjectDir <project> -Gate <pre-script\|pre-code\|pre-render\|delivery>` | 0 all green (WARN does not block) / 1 any FAIL / 2 bad arguments |
| `shots-review.ps1` | **Semantic review**: extracts one frame per beat from `marks.json` and generates a human checklist (chart values / information density / source attribution / hook payoff) | `tools\pipeline\shots-review.ps1 -ProjectDir <project>` | 0 generated / 2 environment error |
| `validate.ps1` | **Publish compliance**: title length, tag count, video exists, cover size (optional), prediction hash lock, daily post count, posting interval, halt switch, audio loudness | `tools\gate\validate.ps1 -Title ... -TagsCount ... -VideoPath ... -PredictionPath ...` | 0 can publish / 1 blocked |

Helper tools:

| Tool | Purpose |
|---|---|
| `tools\pipeline\blind-read-check.py` | Generates a "blind retelling" prompt for an isolated reviewer that only sees the script |
| `tools\pipeline\compress-audit.py` | Compares `article.md` with `script.md` to find framework/transition sentences that were cut too aggressively |
| `tools\pipeline\normalize-bom.ps1` | Normalizes the UTF-8 BOM of `.ps1` files to exactly 1 (required for Chinese text under Windows PowerShell 5.1) |
| `tools\record\shot.mjs` | Captures a single screenshot, for debugging one step's visuals |

> Machine gates only cover what can be proven. Whether a chart's numbers match the narration, whether examples are attributed, whether the hook is paid off — those can only be checked by a human ticking the list generated by `shots-review.ps1`.

---

## 7. Optional: Unattended Heartbeat

`tools\pipeline\heartbeat.ps1` is an **optional** launcher: a scheduler (such as Trae Schedule or Windows Task Scheduler) starts it periodically, and it lets the agent read `backlog.json` and keep working through the queue.

What it does: complete the PATH → invoke your agent CLI → write stdout/stderr to `cache\heartbeat\*.log`.

```powershell
$env:CODEBUDDY_CLI = "C:\Users\<you>\AppData\Roaming\npm\codebuddy.ps1"  # or your agent CLI
$env:HEARTBEAT_MODEL = ""          # empty = use the CLI default model
$env:HEARTBEAT_PROMPT = "run the heartbeat"  # instruction passed to the CLI
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\heartbeat.ps1
```

**Risk warning**: unattended means the agent writes files and runs commands while nobody is watching. Please:

- Only enable it in repositories you trust, and start with a small `-WhatIf`-style task
- Keep the `halt` circuit breaker: `validate.ps1` checks the halt file and blocks publishing when it exists
- Periodically read `cache\heartbeat\*.log`; do not let it become a black box
- Do not put sensitive information into the `backlog.json` queue

If you have no scheduling need, **do not enable it**. Running the flow manually is entirely sufficient.

---

## 8. Repository Layout

```
xhs-video-agent/
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   ├── WORKFLOW.md            # End-to-end process (the most detailed spec)
│   ├── CHEAT-WORKFLOW.md      # Cheat calibration loop cheat sheet
│   ├── VIDEO-GUIDE.md         # Video-line environment conventions + pitfalls + 3:4 patch list
│   ├── RUBRIC.md              # v1-retention five-dimension scoring rules
│   ├── LESSONS.md             # Hard lessons from shipped videos (read before starting)
│   └── SCRIPT-PATTERNS.md     # Writing pattern library
├── tools/
│   ├── gate/validate.ps1      # Publish compliance gate (9 checks)
│   ├── pipeline/
│   │   ├── check.ps1          # Process contract gate
│   │   ├── shots-review.ps1   # Per-beat frame extraction for review
│   │   ├── blind-read-check.py
│   │   ├── compress-audit.py
│   │   ├── normalize-bom.ps1
│   │   ├── heartbeat.ps1      # Optional heartbeat
│   │   └── terminology.txt    # Terminology list (narration wording constraints)
│   ├── record/
│   │   ├── record.mjs         # Playwright headless recording → webm + marks.json
│   │   ├── shot.mjs           # Single-step screenshot
│   │   ├── build_master.py    # Place audio by marks.json → mp4
│   │   ├── verify_sync.py     # A/V sync cross-correlation check
│   │   └── package.json
│   ├── metrics/
│   │   ├── login.js           # QR-code login to the creator center
│   │   ├── pull.js / pull.ps1 # Fetch backend metrics → data/metrics/latest.json
│   │   └── adapter/           # Data adapters
│   ├── research/fetch_sources.py  # Fetch public sources (Sogou/360/arXiv)
│   └── cover/                 # Optional cover rendering (HTML/CSS → PNG)
├── examples/
│   ├── README.md
│   ├── ep11-sampling/         # All text assets of one complete video
│   └── shots/                 # Frames from the final video ×5
├── templates/
│   ├── account.md             # Account profile template
│   ├── log.md                 # Publishing log template
│   └── episode/               # Five skeletons for one episode
└── (generated at runtime, all gitignored)
    ├── videos/<episode>/      # Your per-episode projects
    ├── predictions/           # Blind prediction files
    ├── data/metrics/          # Backend metrics
    ├── cache/                 # Cache and heartbeat logs
    └── account.md / log.md    # Your private account profile
```

### Environment variables

All scripts default to the **repository root** and only read environment variables when you need to override:

| Variable | Purpose | Default |
|---|---|---|
| `CHROME_PATH` | Chrome executable | `C:/Program Files/Google/Chrome/Application/chrome.exe` |
| `VIDEO_PROJECT` | Episode video directory | `videos/personal-agent-deep-dive` |
| `PRESENTATION_DIR` | Web project directory | `<VIDEO_PROJECT>/presentation[-vertical]` |
| `VARIANT` | `wide` (16:9) / `vertical` (3:4) | `wide` |
| `PORT` | Dev server port used during recording | 5174 / 5175 |
| `TOTAL_STEPS` | Total step count | Read from `<PRESENTATION_DIR>/audio-segments.json` |
| `TRAIL_MS` | Dwell time after each beat's audio | 1500 |
| `STORAGE_KEY` | Browser cursor key (bump when step count changes) | `presentation-cursor-v8` |
| `FFMPEG` | ffmpeg executable | PATH → bundled `@ffmpeg-installer` |
| `NODE_EXE` | node executable | `node` |
| `PW_CORE` | playwright-core directory | `tools/record/node_modules/playwright-core` |
| `PULL_URL` | Backend metrics page URL | Built into the script |
| `CODEBUDDY_CLI` / `HEARTBEAT_MODEL` / `HEARTBEAT_PROMPT` | Heartbeat launcher parameters | See section 7 |

---

## 9. Example Walkthrough

[`examples/ep11-sampling/`](examples/ep11-sampling/) contains **all text assets** of one real published video, ordered by pipeline stage:

| File | Position in the flow | What to look at |
|---|---|---|
| [`article.md`](examples/ep11-sampling/article.md) | Phase 0 input | Source material: why the same question gets different answers |
| [`facts.md`](examples/ep11-sampling/facts.md) | Phase 0 output | 4 public sources + cross-relations + scope boundaries + teaching design + argument chain |
| [`design-intent.md`](examples/ep11-sampling/design-intent.md) | Before writing | Three questions: which metric / which reference video / which lesson to avoid |
| [`script.md`](examples/ep11-sampling/script.md) | Phase 1 | 13-beat narration, separated by `---`, written as paragraphs rather than subtitle lines |
| [`outline.md`](examples/ep11-sampling/outline.md) | Phase 1 | Per-step visuals / elements / transitions / visual focus / reading-protection duration |
| [`script-selfcheck.md`](examples/ep11-sampling/script-selfcheck.md) | Phase 1 gate | Four-layer self-check pass/fail + opening three elements + blind retelling record |
| [`beats.json`](examples/ep11-sampling/beats.json) | Phase 1 output | Millisecond beat table; `marks.json` wins after recording |

See [`examples/README.md`](examples/README.md) for what each file does and "how to imitate it". **Do not copy the wording** — copy the structure, the checklists, and the scope boundaries. The script has to be your own topic.

---

## 10. FAQ

**Q1. The page opens but there is no sound when I click?**
That is Manual mode by design; it does not play audio. Record with `?auto=1`, or press `M` to switch to Audio mode. The recording script always visits `?auto=1`.

**Q2. Why does `?auto=1` require pressing Space?**
Browser autoplay policy requires one user gesture. The page has an `AutoStartGate`, and `record.mjs` presses Space itself after load — so headless recording needs no interaction. You only press once when previewing manually in a browser.

**Q3. Do I still need a cover image?**
No, by default. The platform uses the first frame, so beat 1 carries the cover duty: a large title + hook + information that reads at a glance. `tools/cover/` still works (`python tools\cover\cover.py --help` for options), but `validate.ps1 -CoverPath` is optional and only emits a WARN when omitted.

**Q4. `edge-tts: command not found`?**
Python's `Scripts` directory is not on PATH. Use `python -m site --user-base` to find the user-level Scripts directory, or verify with `python -m edge_tts --version`; add it to PATH and reopen the terminal.

**Q5. ffmpeg not found?**
Three sources in priority order: `$env:FFMPEG` → `tools/record/node_modules/@ffmpeg-installer/win32-x64/ffmpeg.exe` (available after `npm install`) → `ffmpeg` on PATH. If none exist, run `winget install Gyan.FFmpeg` or download from ffmpeg.org.

**Q6. The video runs over 180 seconds — what now?**
Check the C14 duration estimate in `check.ps1` (`Chinese characters / 4 + beats × 1.5`, or `English words / 2.8 + beats × 1.5` for English scripts). Trim beats rather than speeding up narration: delete beats that repeat explanations, merge adjacent parallel concepts. In practice the 60-second format is hard to follow; only use it when `design-intent.md` explicitly says there is a single point.

**Q7. What is a blind prediction, and why can't I change it?**
Before publishing you write down "how far this will go", then hash-lock it. Editing the prediction after publishing contaminates the calibration sample, making every later retro untrustworthy. `validate.ps1` verifies the hash and blocks publishing if it changed.

**Q8. The backend login expired?**
Re-run `node tools\metrics\login.js` and scan the QR code to generate a new `tools\metrics\session.json`. Neither that file nor the cookies ever enter the repository.

**Q9. What if the upstream skill does not support 3:4?**
Apply the four-item local patch in [docs/VIDEO-GUIDE.md](docs/VIDEO-GUIDE.md) §3.2. The core is adding `stage.config.ts` as the single source of truth for `STAGE_W/STAGE_H`, and making `scaffold.sh` accept `--ratio=3:4`. Without the patch you can still run the whole chain in 16:9.

**Q10. Why are all script paths relative?**
So the repo runs from any clone location. Scripts derive the repo root from their own location (`$PSScriptRoot\..\..` / `path.resolve(__dirname, '../..')`). To point at another project, use the environment variables in section 8 — do not hard-code absolute paths.

**Q11. Can I use only part of it?**
Yes. `tools/record` (recording + audio muxing) and `tools/gate` are standalone; the front end can be any web page that auto-advances under `?auto=1`. The cheat loop can also be used with only the rubric and retro table.

**Q12. Does it support macOS / Linux?**
The core Node / Python scripts are cross-platform, but `check.ps1`, `validate.ps1`, `shots-review.ps1`, and `heartbeat.ps1` depend on Windows PowerShell 5.1 and `System.Drawing`. It has only been verified on Windows.

---

## 11. Known Limitations

- **Verified on Windows only**: PowerShell 5.1, `System.Drawing`, and the default Chrome path assumption all lean Windows.
- **The 3:4 patch is not in this repo**: the upstream skill only supports 16:9; the portrait conversion is a manual checklist (section 4.5 / VIDEO-GUIDE §3.2).
- **No mp4 in examples**: the repo only ships text assets and screenshots to avoid size and copyright issues; you have to produce the final video yourself.
- **Publishing depends on a third-party MCP**: xiaohongshu-mcp's interfaces and page structure may change with the platform, and login state expires.
- **Backend metrics scraping is fragile**: `tools/metrics` depends on the creator center's page structure and needs selector updates after redesigns.
- **No CI / tests / Docker**: an intentional trade-off — the core of this pipeline is content and judgment, not engineering infrastructure.
- **TTS is synthetic**: edge-tts is free and stable, but it is not a human voice. If voice quality matters, switch providers.
- **The rubric was calibrated on the author's account**: the five-dimension weights may not be optimal for your niche; ship 3 videos first, then tune them with your own data.

---

## 12. Dependencies & Credits

This repository **does not include** the source code of the following projects; it only calls them by convention, and copyright belongs to their respective authors:

| Project | Author/source | Role in this flow |
|---|---|---|
| [web-video-presentation](https://github.com/ConardLi/garden-skills) | ConardLi | Narration script → Vite + React web presentation |
| [cheat-on-content](https://github.com/XBuilderLAB/cheat-on-content) | XBuilderLAB | Scoring / blind prediction / retro calibration loop |
| [redbook-creator-publish](https://lobehub.com/skills/rov639-skillhub-redbook-creator-publish) | rov639 | Image-post publishing package (optional) |
| [atutun-xhs-cover](https://github.com/panggungunvibe/atutun-xhs-cover) | panggungunvibe | Atutun-style cover prompts (optional) |
| [xiaohongshu-mcp](https://github.com/xpzouying/xiaohongshu-mcp) | xpzouying | Publishing and in-platform search |
| [Playwright](https://playwright.dev/) | Microsoft | Headless recording and screenshots |
| [edge-tts](https://github.com/rany2/edge-tts) | rany2 | Free Chinese voice-over |
| [ffmpeg](https://ffmpeg.org/) | FFmpeg community | A/V muxing and frame extraction |

The parts written for this repository (`tools/`, `templates/`, and the method descriptions in `docs/`) are licensed under MIT. Source citations in the examples (OpenAI Help Center, arXiv:1904.09751, Thinking Machines technical report, etc.) remain the property of their original authors and are used only as factual references.

---

## 13. License

[MIT](LICENSE) © 2026 xhs-video-agent contributors
