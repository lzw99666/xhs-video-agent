# Xiaohongshu Operations Workflow (Consolidated)

> This file is part of xhs-video-agent; the sample data comes from the author's account and is only used to illustrate the method.
>
> This file connects the two Xiaohongshu content lines (image posts / video) + publishing + retro into one end-to-end, executable description.
> The account profile is defined by `account.md`, publishing records by `log.md`; those two are the "external memory" of this workflow.
> Last consolidated: 2026-10-11 (added the cheat-on-content calibration loop layer, see section 8).

---

## 0. Overview

| Content line | Authoring tool | Artifact spec | Distribution | Publishing |
|---|---|---|---|---|
| Image-post line | `redbook-creator-publish` skill + Pillow image scripts | 3:4 portrait 1080x1440 image posts | Xiaohongshu | `xiaohongshu-mcp` -> `publish_content` |
| Video line | `web-video-presentation` skill + `tools/record` production pipeline | 3:4 portrait 1080x1440 video | Xiaohongshu (also works for 16:9 on Bilibili) | `xiaohongshu-mcp` -> `publish_with_video` |

Both lines share the "sincere learner" persona (`account.md`) and do not interfere with each other. **Every publish action must be confirmed by a human** (hard constraint in the skill + write-operation gate in the MCP).

---

## 1. Directory structure

```
<repo-root>\
├── account.md            # account profile (single source of settings; read before every creation session)
├── log.md                # operations log (publishing records + weekly retros; append after every publish)
├── WORKFLOW.md           # this file
├── VIDEO-GUIDE.md        # video-line supplement (environment conventions / pitfalls)
├── DEPLOY.md             # MCP deployment notes (startup / connector / login)
├── assets\               # shared assets (banner etc.)
├── cache\                # runtime cache (login QR code etc.)
├── posts\                # image-post packages (one directory per date, includes Pillow image scripts)
│   └── 2026-10-09-personal-agent\
│       ├── note-01.md / note-02.md   # publish package (title / body / image list / tags / risks)
│       └── gen_images.py / gen_images_02.py   # 1080x1440 cover / inner-page generators
├── skills\
│   ├── redbook-creator-publish\      # image-post authoring skill (from lobehub/rov639 v1.0.0)
│   ├── web-video-presentation\       # video-line skill (v1.2.2, locally extended with a 3:4 variant)
│   ├── cheat-on-content\             # content calibration prediction loop (XBuilderLAB v0.1.0, 14 sub-skills, see section 8)
│   └── atutun-xhs-cover\             # viral cover-image prompt generator (panggungunvibe/atutun-xhs-cover, Atuntun style; produces cover-image prompts to feed text_to_image and render a 1080x1440 cover)
├── tools\record\         # video production pipeline (written for this project, not bundled with the skill)
│   ├── record.mjs        # Playwright headless screen recording (?auto=1)
│   ├── build_master.py   # concatenate audio + assemble mp4 (the popping bug is fixed)
│   └── verify_sync.py    # audio/video sync cross-correlation check
├── tools\cover\          # shared cover renderer (used by every video line, not bundled with the skill)
│   ├── cover.py          # Atuntun-style HTML/CSS -> Playwright screenshot -> 1080x1440 cover
│   └── README.md         # usage and parameters
├── videos\               # video-line projects (one subdirectory per video)
│   └── personal-agent-deep-dive\     # first video shipped (personal-agent-vertical.mp4)
└── mcp\                  # Xiaohongshu MCP service (the Bilibili line was retired and deleted on 2026-10-10)
    ├── xiaohongshu-mcp.exe / start-mcp.ps1 / xiaohongshu-login.exe
    └── cookies.json      # login session (long-lived; rescan when it expires)
```

---

## 2. Image-post line flow

### 2.1 Authoring (redbook-creator-publish)
Before every session, **read `account.md` + `log.md` first**, then produce according to persona / topic strategy / red lines:
1. **Topic**: the user supplies one, or the AI researches current AI / tool / product topics; offer options before drafting.
2. **Draft**: title <= 20 Chinese characters, strong hook opening, 3-6 short paragraphs, actionable suggestions, image suggestions, tags.
3. **Image plan**: for each image define purpose / card copy / style / ratio / source (AI-generated or screenshot).
4. **Publish package**: return structured title / body / image list / tags / first comment / risk notes.

### 2.2 Image rendering (scripted with Pillow, uniform visuals)
Portrait 3:4 = **1080x1440**, light background + Klein blue label blocks, Microsoft YaHei.
- Script: `posts/2026-10-09-personal-agent/gen_images.py` (cover / inner pages generated in one go)
- Palette: background `#F5F5F0`, body `#1A1A1A`, secondary gray `#8A8A85`, primary `#2B5BFF`, card white `#FFFFFF`
- Fonts: `C:/Windows/Fonts/msyhbd.ttc` (bold), `msyh.ttc` (regular)
- Run (Windows): `python posts\2026-10-09-personal-agent\gen_images_02.py` -> output into `images/`
- Conceptual diagrams may be AI-generated; for code / hands-on content **prefer publicly verifiable material** (official docs / screenshots of public tutorial pages, **cite the source**); local note screenshots are only an **optional** supplement.

### 2.3 Publishing (see the MCP in section 4)
`publish_content(title, content[do not hand-write #tags in the body], list of absolute image paths, tags[])` -- topic tags always go through the `tags[]` array parameter (3-6 domain / category tags; the platform renders them as #topics for vertical traffic); do not hand-write them in the body.

---

## 3. Video line flow

### 3.1 Standard flow (web-video-presentation)
```
Phase 0 Research (added 2026-10-17, borrowed from the stage-play pipeline's "step one"):
        the regular line / CS188 line first produce the facts.md research card -- source list + key data (with provenance) +
        abstract concept -> visual metaphor mapping. "No writing before solid research": script writing is forbidden while facts.md is not finalized.
        [Material sourcing (added 2026-10-18)] Material sourcing **prefers public retrieval** (official docs / public tutorials /
        papers), and **multi-source cross-checking is mandatory**: >= 2 independent sources, of which >= 1 is public; local study material is only an
        optional reference, **not a sourcing constraint** ("self-taught non-CS grad learning AI" is a narrative persona, it does not limit sourcing scope).
        Reusing someone else's examples / numbers requires citing the source; **single-source paraphrase with zero cross-checking is forbidden**.
        > Search tools (settled 2026-10-18): first choice is the Xiaohongshu MCP `search_feeds` (same-platform notes +
          real engagement numbers, same-platform benchmarking); supplement public evidence with `python tools\research\fetch_sources.py`
          (Sogou/360 + arXiv, pure stdlib, zero dependencies). Both **serve only the source layer of facts.md**,
          **and must not be used as a topic source** (topics belong to the section 8 cheat chain).
        [Instructional design (added 2026-10-18, cures "bad content")] facts.md must contain a "## 4. Instructional design" section,
        all 6 sub-items are mandatory (this is what upgrades facts from a "fact ledger" to a "teaching script"):
          1 **Learning objective**: what viewers can do after watching (one sentence, actionable)
          2 **Viewer prior assumptions**: what you assume they know / do not know (how deep terms must be explained)
          3 **Full context of every example**: what the problem is, where the candidates came from, why these ones
          4 **Experience translation**: what viewers will "feel" about this number / mechanism change
          5 **Ending landing point**: actionable advice + the callback sentence that closes the opening hook
          6 **Argument chain / narrative arc** (added 2026-10-19): first lock the film's argument order in one sentence
             (e.g. what it moves on -> how it sees -> so where it fails -> whether you should use it ->
              how people actually use it -> advice for you), and state chapter by chapter **which question of the previous chapter this one picks up**
        This section is checked by the pre-script gate (check.ps1 C7). **Adjusted 2026-10-19**: C7 was
        downgraded from FAIL to WARN -- content quality now relies mainly on the skill's built-in QC (SCRIPT-STYLE three-layer
        self-check + CHAPTER-CRAFT completion self-check); mechanical assertions are reminders only and no longer hard-block (to avoid
        "constraining" copy quality with hardcoded rules).
        [Evidence list (added 2026-10-18, persona red line)] If the script contains first-person experience statements
        (I hit this / I tested it / I built it / I tried it / I got it running / I myself...), facts.md must contain
        a "## 5. Evidence list" section listing the real record behind each such statement (date / file / source);
        without evidence you may not write it (red line: never fabricate personal experience or measured data). Enforced by the pre-code / delivery
        gates (check.ps1 C8): if matched and there is no evidence, it FAILs.
        The gh-daily line is exempt (fetch.py's topic card is the research layer; do not duplicate it).
   ▼ [Gate check.ps1 -Gate pre-script] Verify facts is finalized (sources/data sections present, no placeholders)
Phase 1 Content: facts.md + source article -> AI produces script.md (narration script) + outline.md (chapters/steps
        + shot elements: each step labeled with transition method / visual focus movement / reading-protection duration) + beats.json (beat table)
        [Copy QC (added 2026-10-19, cures "bad copy")] Before writing the script you **must read**
        `skills\web-video-presentation\references\SCRIPT-STYLE.md` (the skill's built-in
        narration-script spec, **no external skill is introduced**), and walk through its **four-layer self-check**
        (form layer: 8 principles / backbone layer: five kinds of AI flavor removal / read-it-aloud test / structure layer: category tree + transitions) item by item -> revise per failed items -> save
        `script-selfcheck.md` as evidence (item-by-item pass/fail + evidence + what changed).
        **Without script-selfcheck.md you may not enter Phase 2** (checked by the pre-code gate).
        [Opening three elements (added 2026-10-31, cures "no background at the start / viewers do not follow")] SCRIPT-STYLE layer four
        item 7 has been upgraded to three elements: **who** (the subject noun, not just "it") / **what is going on** (the topic) /
        **why it is worth watching** (its relation to the viewer). Any one missing in the first 2 beats = a dangling opening.
        The selfcheck must record PASS/MISSING for each of the three + the item-5 blind-read text; C10 checks this,
        and any missing item is a direct FAIL (ep11 failed on the opening four versions in a row, see `docs/LESSONS.md`).
        **Executor**: the agent running this task must review it personally (from a stranger viewer's perspective); there is no human interruption point and
        no outsourcing to a person; revise right after reviewing, review again after revising, and only enter Phase 2 when all three PASS.
        > every outline step must carry an `element:` field (see 3.11): pick a concrete viz-library element
          that relates to this beat's narration, **>= 1 per step**; if you cannot name one, that step's frame will be empty.
   ▼ [Gate check.ps1 -Gate pre-code] Verify the facts+script+outline triad and that step counts match
         + script-selfcheck.md contains the opening three-element verdict and the blind-read record (C10)
         + duration estimate falls within 120-180s (C14, WARN only)
         + backlog/.cheat-state is parseable (C15, FAIL)
   ▼ [Checkpoint 1 · hard node] Align on 6 things at once: research card / script / outline / theme / material / development mode
Phase 2 Development: scaffold the project -> read CHAPTER-CRAFT.md (mandatory per chapter) -> finish chapter 1 completely
        [Frame density (added 2026-10-19, cures "empty frames / content covers only 1/3 of the screen")] The root node uses
        `.stage-3band` (top hook line / center main visual / bottom annotation line), the center main visual occupies
        **>= 55%** of the stage height; every step must mount at least 1 concrete element from `templates/src/components/viz/`
        (11 pure SVG elements: browser window / terminal / folder tree / doc stack / chat bubbles / card grid / pipeline flow /
        timeline rail / bar chart / loop arrow / magnifier). A chapter with only "title + one paragraph" = acceptance fails.
   ▼ [Checkpoint 2 · hard node] Human acceptance of chapter 1 (visuals / pacing / AI flavor)
   ▼ Chapters 2..N (chapter-by-chapter confirmation / sequential development / parallel subagents)
   ▼ [Checkpoint 3 · hard node] Synthesize audio or not
Phase 3 Audio: extract-narrations -> TTS (Kokoro offline, see 4.x) batch synthesis -> public/audio/
   ▼ [Gate check.ps1 -Gate pre-render] Verify count conservation (C4) + audio exists and is non-empty (C6)
Phase 4 Recording: ?auto=1 one continuous take (press Space once the first time to start) -> record.mjs writes marks.json (master timeline)
   ▼ [Gate check.ps1 -Gate delivery] All assertions + master timeline coverage/frame count (C5); WARN promoted to FAIL
   ▼ [Frame extraction visual review shots-review.ps1 (added 2026-10-18, manual)] Extract a frame per beat from marks.json -> generate
         a review checklist, check the semantic issues machines cannot catch (chart values consistent / information load per beat / example source labels /
         hook callback and transitions / whitespace pacing). See 3.10.
   ▼ [Gate validate.ps1] Publish compliance (before publishing, see section 4)
```

Four "external memory" files: `facts.md` (facts and metaphors; required for the regular / CS188 lines) / `article.md` (material) / `script.md` (pacing) / `outline.md` (chapter splitting + shot elements).
Single source of truth: `narrations.ts` in each chapter (array length = step count = audio file count); after changing the step count you must bump the `STORAGE_KEY` in `useStepper.ts`, otherwise the cursor misaligns.

### 3.2 Key changes for the Xiaohongshu portrait format (3:4)
The skill natively supports only 16:9; **this project has been locally modified to support 3:4** (changes live in `skills/web-video-presentation`):
- Added `templates/src/stage.config.ts` (single source of truth for STAGE_W/STAGE_H)
- `scaffold.sh` accepts `--ratio=3:4` (-> 1080x1440) / `9:16` (-> 1080x1920) / any `W:H`
- Generate a project: `bash scaffold.sh ./presentation --ratio=3:4` -> `src/stage.config.ts` will be 1080x1440
- Set the recording viewport to 1080x1440; watch for portrait adaptations such as oversized sliders and compressed paragraph spacing

> WARNING: the portrait changes have not been merged upstream yet (see the PR to-do in section 6).

### 3.3 Production pipeline (tools/record, written for this project)
The skill docs prescribe OBS/DaVinci for splicing multi-segment audio; this project replaces that with Playwright recording + a Python splicer:
```bash
# 1) record the screen (VARIANT=vertical uses the portrait project)
node tools/record/record.mjs           # record 79 steps per ?auto=1 (full step-through)
# 2) concatenate audio + assemble mp4
VARIANT=vertical python tools/record/build_master.py
# 3) audio/video sync check
python tools/record/verify_sync.py
```
- Local verification build: `personal-agent-vertical.mkv` (48k lossless PCM; zero popping when scrubbing / changing speed)
- Upload build: `personal-agent-vertical.mp4` (48k AAC; clean source for the platform's second transcode)
- **Reading-protection time**: auto advance = audio finished + dwell time for the viewer to digest. Template default 1500ms (the stage-play pipeline's "1.5s stay after reading" standard, since 2026-10-17); adjustable per film: set `TRAIL_MS=800` before recording (passed through as the page's `?trail=`); if one step needs longer protection -> split the step / lengthen the narration, do not change code
- Track alignment is unaffected by trail changes: `build_master.py` places audio using the per-step switch timestamps measured in marks.json, not by accumulating durations
- Popping root cause already fixed: when `build_master.py` spliced 79 segments, `int(seconds * byte rate)` produced an **odd byte offset**,
  and the samples were byte-swapped into high-frequency garbage (720k pulses). Fix: align the offset to the sample grid with `int(seconds * sample rate) * 2` (always even).

### 3.4 Environment conventions (a major pitfall area)
- Use **Git Bash** for bash (bundled with Git for Windows; do not use WSL, it is slow and the environment differs)
- Use Windows-native node/npm (do not run them inside WSL)
- Use the free **edge-tts** for TTS (do not install MiniMax mmx); voices `zh-CN-YunxiNeural` (male) / `XiaoxiaoNeural` (female)
- Recommended themes (technical content): `blueprint` / `chalk-garden` / `terminal-green` / `forest-ink`

### 3.5 Cover-image strategy (**no separate cover image from 2026-10-27**)

> **Decision**: starting 2026-10-27 this account **no longer sets a separate cover image**; the platform takes the video's first frame as the cover.
> **Knock-on effects**: (1) cover design moves forward to the **first frame** -- the first beat must carry the big title + hook (taking on the original cover's job), because that frame is the only image in the feed; (2) `validate.ps1 -CoverPath` becomes optional -- if omitted, the cover size check is skipped and `[GATE-WARN]` is printed; (3) retros no longer lose weight for "no cover set"; (4) the `tools\cover` and `atutun-xhs-cover` flows are **retired** (code kept, no longer part of the delivery checklist).

The cover flow as recorded before retirement follows (kept as a rollback reference, not executed by default; if covers are restored later, follow this): use `skills\atutun-xhs-cover\` to generate this video's Xiaohongshu viral cover-image prompt (Atuntun style: real person on camera + oversized pale-yellow #FDFFA7 title + heavy black outline + emoji stickers). On 2026-10-11 ep02 verified unattended CLI invocation works (read the skill body first -> output directly per the procedure, no questions, no scope creep).
- Output: one cover-image prompt that can be fed straight to an image-generation model (target size 1080x1440 portrait), one primary option plus one alternative
- The skill is natively **interactive** (asks 8 style questions one by one); when invoked unattended the CLI skips the questions and picks the best-fitting style for the content (default style 1 big-type-on-top / style 4 tutorial checklist) and outputs directly
- **Final image rendering (shared tool, used by every video line)**: once the prompt is out, run `python tools\cover\cover.py --title "<main title>" --subtitle "<subtitle>" --person <person image> --style <1|4> --out <cover.png>` (Atuntun-spec HTML/CSS -> Playwright headless screenshot, strictly 1080x1440; large Chinese type goes through HTML, not text-to-image, to avoid wrong glyphs; the person image is only circle-cropped + outlined, generating / redrawing faces is forbidden). See `tools\cover\README.md` for usage.
- **Sticker copy must not leak (ep03 lesson, 2026-10-12)**: text-card stickers render only when `--sticker-label` (with `--sticker-sub`) is passed explicitly; **pass nothing and you get no card**; reusing the previous episode's copy is forbidden (ep03 shipped with ep02's leftover "skill pack / open source / free"). Background code texture is already fixed as theme-neutral decoration. Without a person asset use `--no-person`, and the layout auto-centers vertically with no gap
- **Delivery statement (mandatory)**: the delivery note must list the cover elements -- title / subtitle / sticker copy (or "no card") / person-asset source (or no-person), so the operator can visually verify semantic correctness before publishing (validate.ps1 only checks size, it cannot catch content errors)
- Person asset: a real reference photo of the account owner, or when the content involves a specific person, their public avatar (e.g. a GitHub avatar; note the source in `--caption` and state that it is not an endorsement)
- The cover side-branch depends only on the finalized script (title / subtitle) and **can run in parallel with the main production line**; the finished PNG ships with the publish package and is confirmed by a human before publishing. The MCP has no "change the cover of a published note" tool, so the cover must be ready before publishing
- 8 styles at a glance: 1 big type on top / 2 split giant type / 3 beginner Q&A explainer / 4 tutorial checklist / 5 product review ranking / 6 recommendation list / 7 sticker-collage primer / 8 (see SKILL.md)

### 3.6 Skill daily line: a project-tree chapter (hard requirement)
For any video recommending a GitHub skill/repo (the Skill Daily series), **all material must come from the `gh-daily\` toolchain** (read `gh-daily\PLAN.md` for the battle plan first; fetch.py generates the topic card -> shot.py takes page screenshots -> colors use the measured values in PLAN.md 2.2); pulling fresh data out of README to rebuild it is forbidden. **And the video must include a "project structure tree" chapter**:
- Data source: the `top_paths` field of the topic card in `gh-daily\candidates\<owner>__<repo>.json` (the real path list fetch.py has already collected, 306-400 entries); if there is no topic card, run `python gh-daily\fetch.py` first to generate one
- Presentation: highlight / scroll the directories line by line, with one narration line pointing out the key directories (e.g. `skills/`, `commands/`, where the install script lives)
- Reference: `gh-daily\public-crop-gh-tree.png` is a ready-made GitHub file-tree screenshot style; the "5-20s structure tree scroll" row in PLAN.md 3.3's shot table is this chapter
- Purpose: give viewers a concrete sense of "what this repo actually contains", strengthening information density and save value

### 3.7 Narration beat table (millisecond level, hard input)
Borrowed from the stage-play pipeline's "step two: bamboo copy and narration beat layout". **Once the narration script is finalized you must produce the beat table, as the single time baseline for shot planning and render track alignment**.
- **Beat = one step = one focused idea**: separated by `---` in `script.md`, one paragraph per beat; beat count = the film's total step count
- Artifact `beats.json`, fixed fields: `step_id` / `chapter` / `step` / `start_ms` / `dur_ms` / `text` (units are ms; `step_id` looks like `hook:1`)
- **master timeline (the single time baseline) = `marks.json`**: written by `record.mjs` during the recording playback (`raw\marks.json`), schema `{t0, start, marks:[{id, t}], total}`, `id` = `<chapter>:<step>`. It is the **only source of truth for audio/video track alignment** across the whole film -- forward play / reverse play / speed-changed replay all align to the same set of measured switch timestamps; chapter code and track-alignment logic **always read it and must not hardcode milliseconds**, and **must not substitute cumulative durations**. `beats.json` is its "layout plan" version (estimated or pre-scheduled by TTS); once `marks.json` is written after production, measured values win
- **Duration source priority**: (1) measured TTS -- `npm run extract-narrations` produces `audio-segments.json`, then `record.mjs` writes `marks.json` after recording; (2) without audio, estimate at Chinese ~= 4.5 characters/second, and it **must be labeled "estimate"** -- never pass it off as measured
- **Hard constraints**: shot planning and chapter code **must not hardcode milliseconds/seconds** (except `(~Ts)` narration estimates); track alignment always reads measured values from `marks.json`, never cumulative durations
- **Self-check**: `beats.json` beat count == `narrations.ts` array length == audio file count (single source of truth, see 3.1); coverage checking is done by the C5 assertion in `tools\pipeline\check.ps1` (see 3.9)

### 3.8 Switchable visual style (only prompts change, the code skeleton stays)
Borrowed from the stage-play pipeline: "fix the timeline and action skeleton, change only the prompts to switch styles".
- **Fixed**: timeline, per-step action skeleton, step division, chapter structure, track-alignment logic (`marks.json`)
- **Locked in this project (user decision 2026-10-18)**: the account's single theme = `warm-keynote` (warm cream background `#f5efe1` / ink-brown text `#43302b` / teal accent `#14b8a6`); new films scaffold with `scaffold.sh --theme=warm-keynote`, keeping the whole account visually consistent (the profile banner already matches the warm tone, see `account.md` section 6)
- **Replaceable (a style change touches only this layer)**: (1) the theme tokens in `src/styles/tokens.css` (palette / fonts / motion baseline); `scaffold.sh --theme=<id>` selects a theme, or overwriting this single file later reskins the whole film (23 built-in themes, see `references/THEMES.md`); (2) chapter prompts / visual imagery, which decide "what gets drawn" without changing structure
- **In practice**: the same `script.md` + `outline.md` can feed different themes / prompts, producing paper-cut / blueprint / 2.5D miniature / retro pixel looks while the narration and timeline stay identical
- **Prohibitions**: a style change must not change the step count (if it does, bump the STORAGE_KEY in `useStepper.ts`, see 3.1); never sacrifice audio/video sync for style
- Reference: theme quick reference in `VIDEO-GUIDE.md` section 7 and `skills\web-video-presentation\references\THEMES.md`

### 3.9 Five-step contract gates (check.ps1, added 2026-10-18)
The five-step pipeline (facts -> script/outline -> chapter code -> render -> delivery) **mechanically verifies at every boundary that the previous step is finalized/complete**, preventing "writing before finalizing" and "shipping something broken". Division of labor between `tools\pipeline\check.ps1` and `tools\gate\validate.ps1`: this script owns the **step contracts** (internal consistency before starting work / before delivery), while validate owns **publish compliance** (the external publishing gate).

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 `
    -ProjectDir videos\<episode> -Gate delivery      # after production, before delivery; the strictest
```
| `-Gate` | Timing | Scope |
|---|---|---|
| `pre-script` | Before writing the script | Only verifies facts is finalized (C1) |
| `pre-code` | Before writing chapter code | facts + script + outline (C1~C3: three elements / step counts consistent) |
| `pre-render` | Before production | Adds count conservation (C4) + audio exists and is non-empty (C6) |
| `delivery` | Before delivery / publishing | Everything + timeline consistency (C5, master timeline coverage + frame count); WARN promoted to FAIL |
| `media` | gh-daily line only | Only the media layer: count conservation (C4) + timeline (C5) + audio (C6); skips the three text files |
| `all` | Any time | Verify whatever files exist (default) |

- **Assertions**: C1 facts finalized (exists + contains source list / key data sections + no placeholders) | C2 script finalized (beat count >= 2 + no placeholders) | C3 outline three elements (transition / visual focus / protection) + per-chapter step sum == script beat count | C4 count conservation (narrations == audio-segments == mp3 == beats == script beat count) | C5 master timeline (beats schema + `marks.json` covers all steps + `raw\shots` frame count) | C6 audio exists and is non-empty (> 2048 bytes) | **C7 content usability** (facts instructional-design section with 6 sub-items + ending action sentence + callback in the last 3 beats for the first-beat hook + term first-mention explanation) -- **downgraded to WARN from 2026-10-19**, no longer hard-blocks (content quality is now owned by the skill's built-in QC) | **C8 persona red line** (first-person experience statements in the script must have evidence in facts' "Evidence list") | **C9 frame elements** (whether chapter tsx uses concrete elements from `components/viz`, WARN) | **C10 copy self-check evidence** (`script-selfcheck.md` exists; FAIL at the pre-code / delivery gates)
- **Exit codes**: 0 = all green (WARN does not block); 1 = some FAIL; 2 = argument / environment error
- **Switches**: `-SkipFacts` (used when the gh-daily line is exempt from the research card) | `-Determinism` (improvement B, determinism check: the first run writes a baseline `raw\shots.sha256`, a second render compares frame hashes and flags any mismatch as "random-frame pickup")
- **Where it plugs in**: run the matching gate before and after each heartbeat goal segment; manual task assignment also runs `-Gate delivery` **before delivery**. The deciding field is the backlog goal's `line` field
- **Scope**: verifies against the **current contract** (facts.md + `---` beat splitting + outline three-element table + beats.json, with ep05 as the baseline). `regular-ep03/ep04` are **historical episodes** from before the contract existed; FAIL is expected and **not retrofitted**; the `gh-skill-daily` line has no four-document set at its root, so use **`-Gate media`** to check only count conservation / timeline / audio inside `*-presentation\` (measured on ep02: 32 audio segments passed conservation)

### 3.10 Frame-extraction visual review (shots-review.ps1, added 2026-10-18)
check.ps1 is a **text-level** gate that reads md/json and **cannot read the frame** -- ep06's "bar chart renders only the first bar / the last four beats are just one text card / chart captions do not label the example source" all slipped through it. So after production and before publishing, add a manual visual review:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\shots-review.ps1 `
    -ProjectDir videos\<episode>
```

- Following the master timeline (`marks.json`), extract the frame at the **midpoint** of each beat and generate the `shots-review.md` checklist (each beat includes the narration text + frame path + 4 checkboxes); frames and checklist default to `%TEMP%\shots-review\<ep>\` (a temp area that does not pollute the project directory; `-OutDir` overrides)
- **Check 4 things** (the semantic layer machines cannot catch): (1) whether chart values and labels agree (do bar heights match the percentages) (2) whether each beat carries enough information (guards against "title + an empty card") (3) whether the sources of examples/numbers are labeled in the caption or narration (4) whether the hook is closed at the end, whether chapter transitions hold + whitespace pacing
- On Windows, PATH's ffmpeg is a **broken shim** on this machine; the script automatically falls back to WSL ffmpeg (`wsl -e bash -lc`)
- **Does not block** (it is a manual item), but hard defects found in review (wrong chart / unlabeled source / dangling hook) must be fixed before publishing

> WARNING **Engineering convention**: the .ps1 files under `tools\pipeline\` must be saved as **UTF-8 with BOM**. PowerShell 5 parses BOM-less files as GBK, which garbles Chinese text and triggers syntax errors (`shots-review.ps1` hit this on its first run).

### 3.11 Frame density and the concrete element library (visual-density, added 2026-10-19)

Cures two criticisms from ep07: **empty frames (content covers only 1/3 of the screen)** and **bad copy**.
The former is cured in this section; the latter in the SCRIPT-STYLE four-layer self-check in section 3.1.

**Change locations (all in the skill template layer -> new films inherit them automatically; published content is not retrofitted and ep07 is not remade)**:

| Layer | File | What changed |
|---|---|---|
| Stage | `templates/src/hooks/useStageScale.ts` | margin default 0 -> when the recording viewport == stage size, **scale = 1 full-bleed**, no more cream shell around the edges (the old 80/100px inset shrank the effective area to ~85%) |
| Texture | `themes/warm-keynote/tokens.css` | added `--surface-pattern-z: 3` -> the warm grid is drawn above chapter content, removing "large blocks of empty color" |
| Layout | `templates/src/styles/base.css` | added `.stage-3band` / `.band-top` / `.band-main` (`minmax(55%,1fr)`) / `.band-foot` / `.viz-fill` |
| Recording contract | `templates/src/styles/base.css` | `.scene *` animations/transitions compressed to 110ms with zero delay -> screenshots are guaranteed to be the designed end state (the old 900ms entrance + 650ms stagger was being captured half-finished) |
| Element library | `templates/src/components/viz/` | 11 pure SVG concrete elements + `README.md` selection guide + `index.ts` (copied automatically by `scaffold.sh`) |
| Spec | `references/CHAPTER-CRAFT.md` / `OUTLINE-FORMAT.md` / `SKILL.md` | added hard "layout density" targets + completion self-check items + the mandatory `element:` field in outline |

**Element list (11)**: `BrowserWindow` `Terminal` `FolderTree` `DocStack` `ChatBubbles`
`CardGrid` `PipelineFlow` `TimelineRail` `BarChart` `LoopArrow` `Magnifier`.

**Hard rules**: (1) >= 1 per step, and related to that beat's narration (talking about search -> mount the magnifier; talking about a pipeline -> mount the pipeline);
(2) the center main visual >= 55% of stage height, fills the width, and is 1.5-2x larger than "readable at a glance";
(3) elements must be SVG + theme tokens; emoji / bitmaps / fake data are **forbidden** (numbers are passed in by the caller as real values);
(4) whitespace at the edges stays as before, but **no** header/footer and no fixed bottom-right corner badge.

**Why no external skill was installed for copy**: the user ruled to reuse the skill's **built-in** `SCRIPT-STYLE.md`
(four-layer self-check) + `CHAPTER-CRAFT.md` (completion self-check), rather than introducing a third-party copywriting skill.

---

## 4. Publishing (xiaohongshu-mcp)

### 4.1 Start the service (once per boot)
```powershell
powershell -File <repo-root>\mcp\start-mcp.ps1   # install xiaohongshu-mcp yourself before using this
# once you see "started, HTTP 200" you are done; port 18060
```

### 4.2 Connecting from the IDE (Trae)
Settings -> MCP -> Create -> Manual configuration: type `streamable HTTP`, URL `http://localhost:18060/mcp`.
After connecting you should see 18 tools.

### 4.3 Login (when the session expires)
Say "check the Xiaohongshu login status; if not logged in, give me a QR code" -> scan it; or double-click `mcp\xiaohongshu-login.exe`.
The session is stored in `cookies.json` and lasts a long time.

### 4.4 Tools and hard constraints
| Tool | Description | Notes |
|---|---|---|
| `publish_content` | Publish an image post | title <= 20 characters; do not hand-write `#` in the body, topic tags go through `tags[]` (3-6 domain tags, used for traffic); images must be **absolute paths** |
| `publish_with_video` | Publish a video | **no "claim original" parameter**; **the MCP has no delete-note API** (deleting old notes must be done manually in the App) |
| `check_login_status` / `get_login_qrcode` | Login status / QR code | -- |
| `get_my_profile` / `list_feeds` | Your own notes / feed | `list_feeds` returns only the discovery feed; you cannot get your own note_id from it |

**Human gate**: every write operation (publishing / deleting, which is manual / commenting) must be confirmed by the user first; the AI never clicks publish itself.

### 4.5 Post-publish read-back verification (mandatory · added after the 2026-10-25 incident)

**Incident**: on 2026-10-25, exp10/exp11 were published and the title and body Chinese of both notes **turned entirely into `?`** (garbled text as stored by the platform). Root cause: PowerShell 5.1 handed a UTF-8 JSON string to `Invoke-WebRequest`, which sent it as ANSI, while the server decoded it as UTF-8, collapsing Chinese characters into `U+003F`. The publish API still returned "published successfully", and the caller only printed byte lengths -> the two garbled notes were online for about 3 hours before anyone noticed.

**Mandatory actions (after every publish, before writing back to log)**:

1. Use `tools\publish\verify-note.py` to **read back** the note just published from the platform and assert mechanically: the title is non-empty and contains no `?`, the title matches the expectation, and the body has >= 20 Chinese characters;
   ```
   python tools\publish\verify-note.py --note-id <note_id> --title "<note_id>=<expected title>"
   ```
2. Only exit code **0** allows registering it as "published" in `log.md`; exit code **1** = broken encoding, **do not register**; the account owner must delete it in the App and republish (the MCP has no delete API);
3. If the MCP returns no reading data on read-back, assert only the title/body; read counts still come from manual screenshots.

**Encoding chain requirements**: every JSON body sent to an MCP call must be converted to UTF-8 bytes before sending (`[System.Text.Encoding]::UTF8.GetBytes($json)`); never pass a raw string to `Invoke-WebRequest -Body`; on the Python side always use `json.dumps(..., ensure_ascii=False).encode("utf-8")`.

### 4.6 Data collection (added 2026-10-27 · replaces manual screenshots)

**Background**: the MCP is a precompiled binary that only exposes likes / saves / comments. It has **no** impressions, views, click-through rate, 2-second exit rate, average watch time, follower growth, or daily curves. All of that used to depend on manual screenshots by the account owner, which blocked two retros in a row.

**Approach**: `tools\metrics\pull.js` reads the creator center directly with Playwright + a separate login session.

- **First run / expired session**: `node tools\metrics\login.js` opens a browser and the **account owner scans the QR code once**; the session is stored in `tools\metrics\session.json` (already in `.gitignore`; never commit it, never share it)
- **Routine pull**: `node tools\metrics\pull.js` (or `powershell -File tools\metrics\pull.ps1`)
- **Outputs**: `data\metrics\latest.json` (account 7-day/30-day + all-notes summary) + `data\metrics\history.jsonl` (appended each time, enables trend analysis)
- **Fields**: per note `impressions / reads / ctr / likes / favorites / comments / shares / danmaku / fans_gained / avg_watch_s`; the account side also has `full_view_rate / fans_lost / net_fans / home_visitors / daily_impressions / daily_reads`

**Four hard constraints**:

1. **The main-site cookie (`mcp\cookies.json`) does not work on the creator center** -- the creator center uses a separate CAS login, and reusing the cookie yields 401/406. Do not try.
2. The platform API has **signature verification**; a bare `fetch` returns **406**. You can only "let the page issue its own request + intercept the response"; do not rewrite the implementation to call the API directly.
3. Per-note `exit_view2s_rate` (2-second exit rate), `finish5s_rate` (5-second completion), `play60s_count` live in the `datacenter/note/base` endpoint, but that endpoint is only triggered by the **single-note analysis detail page**; `pull.js` currently covers list summaries, so these 3 fields still require manually opening that note's detail (the endpoint is located; can be wired up later).
4. Pull frequency **<= 2 times/day** to avoid risk control; data lags about 1 day, and `data_last_update_time` is authoritative.

**Workflow integration**: when collecting for `snap-<id>-24h` / `retro-<id>`, **read `data/metrics/latest.json` first** instead of asking for manual screenshots; only when that file lacks a field (e.g. the 2-second exit rate) ask the account owner for a screenshot.

**Adapter protocol integration (2026-10-27)**: `pull.js` is wrapped as the adapter expected by xhs-explore; with `data_collection=adapter` + `enabled_perf_adapters=["xhs-explore"]`, `/cheat-retro` can call it directly.

- **Entry point (use the fixed path; do not locate it with `find ~` -- this project's skills are installed inside the project, not in the home directory)**:
  `bash skills/cheat-on-content/adapters/perf-data/xhs-explore/run.sh <note_id> <video_folder> [script_path]`
  When the upstream `run.sh` detects `tools/metrics/adapter/run.sh` it `exec`s and delegates, and **does not run the Python crawler** (two cookie systems coexisting would fight each other)
- **Local implementation**: `tools\metrics\adapter\run.sh` (reuses `latest.json` if it is within 30h, otherwise runs pull first) + `report.mjs` (renders the upstream-format `report.md`, including impressions/views/ctr/likes-saves-comments/follower growth/average watch + derived ratios)
- **Exit codes (same as upstream)**: 0 success / 1 session expired / 2 missing dependency / 3 other failure; if `report.md` is not generated the exit code is non-zero
- **Prerequisite**: `tools\metrics\session.json` exists. The upstream `.auth-xhs/` is unrelated to this adapter; you do not need a `.venv` or Python playwright
- **Field gaps unchanged**: 2-second exit rate / 5-second completion / play60s still need manual input; `report.md` states this explicitly at the end

**Judging criteria (from 2026-10-27)**: impressions and views are both **outcomes**. Judge content quality on only two things -- `ctr` (the pull of the title + first frame; this account sets no cover image) and `avg_watch_s` / `finish5s_rate` (content retention). Raw impression volume is not part of the judgement.

---

## 5. Visual spec (shared by image posts + video first frames)

> WARNING **Baseline note (2026-10-18)**: this section is the **image-post line** visual baseline from the setup period. All works have since been unified into the video format; the video theme is locked to **`warm-keynote`** (see 3.8) and the profile banner already matches the warm tone (see `account.md` section 6); cover images, if any, are produced by `tools\cover\cover.py` (Atuntun style). Klein blue now survives only in the historical image-post scripts (`posts\...\gen_images*.py`) and is no longer used for new deliveries.

- **Primary color**: Klein blue `#2B5BFF`
- **Background / text**: light background `#F5F5F0` / body `#1A1A1A` / secondary gray `#8A8A85`
- **Size**: image posts & video covers both 3:4 portrait 1080x1440
- **Fonts**: Microsoft YaHei (bold `msyhbd.ttc` / regular `msyh.ttc`)
- **Layout**: light minimalist background + large black title + Klein blue highlight label blocks; one unified template site-wide
- **Account nickname**: `<your account name>`
- **slogan**: `<your one-line claim>`
- **bio**: `<your bio>`

---

## 6. Known issues / pitfalls

1. **Path conventions**: all file paths are relative to the repo root; scripts must not hardcode personal absolute paths.
2. **Popping fixed**: the 1-byte misalignment bug in `build_master.py` is fully fixed (see 3.3); re-rendered films have zero popping.
3. **Video-line 3:4 changes not merged upstream**: the local 3:4 variant is maintained as a patch; it must be reapplied after upstream updates.
4. **First 7 days of account warm-up**: publish only along the study-note line, no traffic-farming; <= 2 posts/day with >= 2h between them (see `account.md`).
5. **Old popping notes deleted**: the old notes were deleted manually in the App (the MCP has no delete API; such operations can only be done in the App).

---

## 7. Quick checklist (before every publish)

- [ ] Read `account.md` + `log.md`
- [ ] Image post: title <= 20 characters, no hand-written `#` in the body, `tags[]` filled with 3-6 domain tags, images generated at 1080x1440
- [ ] Video: facts.md research card finalized (mandatory on the regular / CS188 lines; exempt on the gh-daily line), outline.md contains shot elements (transition / focus / protection duration)
- [ ] Video: `tools\pipeline\check.ps1 -Gate delivery` is all green (step contracts: count conservation / master timeline coverage / non-empty audio, see 3.9)
- [ ] Video: portrait `--ratio=3:4`, sync check passed, no popping (verified by scrubbing / changing speed in VLC)
- [ ] Cover-image prompt generated with atutun-xhs-cover, and the finished cover rendered by `tools\cover\cover.py` (1080x1440 PNG, shipped with the publish package, see 3.5)
- [ ] MCP service started + login session valid
- [ ] No absolute claims (best / first / 100%), no monetization moves; reuse only sparingly and cite the source
- [ ] **Publish action confirmed by the user**
- [ ] **Post-publish read-back passed**: `python tools\publish\verify-note.py --note-id <id> --title "<id>=<title>"` exits 0 (checks whether Chinese turned into `?`, see 4.5)
- [ ] After publishing, write back to `log.md` (note_id / 24h / 7d data)
- [ ] cheat-predict has been run (publishing is only allowed after the blind prediction is saved, see section 8)

---

## 8. cheat-on-content calibration loop (overlay layer)

> The skill itself: `skills\cheat-on-content\` (top-level router + 14 sub-skills).
> Methodology: score -> blind prediction -> publish -> T+3d retro -> evolve the rubric. It **does not replace** the authoring flow in sections 2/3;
> it only instruments three nodes -- "script finished -> publish -> data collection" -- upgrading the data write-back in log.md into a calibratable experiment.

### 8.1 Where it connects to the main flow

```
Topic selection ──▶ cheat-seed (one-off) / cheat-recommend + cheat-trends (daily candidate pool)
         Trend-source adapters (wired 2026-10-18): `aihot` (AI-vertical trend source; skills\aihot installed and written into
         .cheat-state.json enabled_trend_sources, with manual-paste as the fallback). Note aihot's license scope:
         free for personal non-commercial / public-interest / internal organizational use; **external commercial use requires prior written authorization from AIHOT** (see its LICENSE)
Script finalized ──▶ human review (existing gates unchanged) ──▶ cheat-predict (five-dimension scoring + blind prediction saved) ★ hard gate before publishing; on save the sha256 of the "## Prediction" section goes into .cheat-state.json prediction_hashes (hash lock)
MCP publish ──▶ cheat-publish (register as published, buffer -1)
T+24h/3d/7d data collection (automatic via heartbeat, see 9.1) ──▶ log.md write-back ──▶ cheat-retro (verifies the hash lock first; prediction vs actual retro, append-only)
Accumulate 5+ samples ──▶ cheat-bump (full re-score + cross-model audit before the rubric upgrade)
```

**Tiered integration (user decision 2026-10-12)**: the depth of cheat integration has two tiers by content line --
- **Launch series** (skill-recommended gh-daily line, CS188 course-note line): **partial run**. The topic layer (seed/recommend/trends) is skipped -- topics are fixed externally by the pipeline / course syllabus; but the predict -> publish -> retro **main chain must run**, because the series' mission is to accumulate "prediction vs actual" samples to feed bump self-evolution
- **Every other work + account operation direction** (`line: regular`): **full run**, including the topic layer; the CLI autonomously uses recommend/trends to maintain the candidate pool, do persona analysis, and assess bumps, with no item-by-item human intervention
- Deciding field: the backlog goal's `line` field (`series-skill-daily` / `series-cs188` / `regular`; when absent, treat it as regular full run). Prediction files and retros must both carry this label; bumps evaluate by line group so samples of different formats do not pollute each other's rubric weights
- Sequencing logic: the series is the starter (gets the loop spinning and samples accumulating); once the account's baseline rhythm is running, operating control is gradually handed to the skill's full loop

### 8.2 State and record division of labor

- cheat state files (`.cheat-state.json`, prediction/retro files) are created at this project's root by cheat-init; **say "initialize cheat-on-content" before the first use**
- `log.md` remains the single source of truth for publishing records (note_id / data); cheat files are its "prediction-deviation" extension layer, and both sides link the same note by note_id
- **Both lines are instrumented** (image posts and video; Xiaohongshu impression counts are quantifiable, satisfying the methodology's precondition)

### 8.3 Trae environment adaptation notes

- Claude Code's slash-commands and `hooks/prediction-immutability.sh` **do not work** in this environment: sub-skills are triggered in natural language per the top-level router table; "the prediction section is immutable once written" relies on humans honoring the protocol (see `shared-references/blind-prediction-protocol.md`)
- The current rubric is this account's own **v1-retention (five dimensions HO/PE/TK/NA/QL)**; its objective function is average watch seconds, not impressions (axis changed 2026-10-27, see the header note of `RUBRIC.md` and `cache/bump-20261024-draft.md`)
- During cold start, only five-dimension scoring + a one-line bet are required; numeric predictions are not mandatory (avoiding false precision)
- Recommended: run `cheat-learn-from` soon to import 2-3 similar study creators as the initial signal source
- **hooks verified unusable** (measured 2026-10-12: WorkBuddy CLI v2.164.0's settings have no hooks config domain; PreToolUse/SessionStart are silently ignored). All substitutes live at the protocol layer: immutability -> hash lock (see 8.1 and 9.1), meta-logging -> each node appends to `.cheat-cache/usage.jsonl` on its own, session-start -> the mandatory read list in CODEBUDDY.md

### 8.4 cheat -> authoring: a three-stage loop (added 2026-10-27)

> Purpose: so that cheat does not only instrument two points ("score after the script is final / retro after publishing"), but **influences the content itself from topic selection onward**.
> **Principle: no forms, no templates.** The rubric is a list of questions, not a scorecard; how the hook opens, how the structure is arranged, which example is chosen -- the CLI decides for this specific piece, and the rubric only provides constraints (see the hard-constraint section of `RUBRIC.md`).

| Node | Action | Artifact |
|---|---|---|
| **Before authoring** (before writing the script) | Read the current formula in `RUBRIC.md` + `data/metrics/latest.json` + `LESSONS.md` + the latest retro; answer three questions | `videos\<episode>\design-intent.md` (free text, >= 1 paragraph, no tables) |
| **During authoring** (after the script is finalized) | Self-score on the five dimensions, each with a score + a line from the script as evidence; any dimension <= 2 must be fixed or its reason for keeping must be written. **Add a "one-sentence retell": reading only the script, answer in one sentence "who gets hit / what happened / what should I do" -- if any of the three is missing, revise the script** (2026-10-30 ep10 lesson: five-dimension score 9.29 yet the user did not understand it at all) | Append a `## cheat view` section to `script-selfcheck.md` |
| **After authoring** (retro) | Judge "which dimension predicted well / which predicted wrong", compress into one line + one action for the next post | Append one line to `LESSONS.md`; the evidence still goes into `rubric-memo.md` |

The three questions (must use this piece's concrete numbers and concrete script; if you cannot write them, stop and ask a human):
1. Which metric should this piece move, and to what target number (take it from the distribution in `latest.json`; wishing is not allowed)
2. Which of your own historical notes is the reference, and why is it comparable (same format / same duration / same audience), and what did it do right
3. Which entry in `LESSONS.md` does this piece avoid, and what is this piece's concrete action

Linkage rules:
- The "target metric + number" in `design-intent.md` must agree with the midpoint saved by `cheat-predict`; when they disagree, design-intent wins, and the reason is noted in the prediction file
- Self-scores **do not replace** the blind sub-agent's scoring; when the two differ by >= 2 points, state in the prediction file where the difference lies
- The retro's lesson line contains only executable actions, not conclusions like "the data was bad this time"
- These three steps are **judgements**, not deliverables: no invented numbers, no copying the previous piece's design-intent
- `check.ps1`'s C13 only emits a **WARN** at the pre-script gate when `design-intent.md` is missing / too short; it does not block (content quality is not constrained by hardcoded rules)

---

## 9. Autonomous operations architecture (heartbeat + backlog + gates)

> Target state: the human retreats to an audit seat, and the CLI pulls work autonomously from scheduled heartbeats. Three improvements (1 data collection 2 autonomous heartbeat 3 SOP evolution) were implemented per the user's 2026-10-12 decision.

### 9.1 Data collection nodes (sensor loop, improvement 1)

- **Data sources (section 4.6 takes the lead from 2026-10-27)**:
  - `data\metrics\latest.json` (`node tools\metrics\pull.js`, Playwright reads the creator center): impressions / views / ctr / likes / saves / comments / follower growth / **average watch seconds** / account 7-day and 30-day summaries + daily curves
  - xiaohongshu MCP **read-only tools** fill in the event stream: `get_my_profile` (follower / total-like counts, xsecToken), `get_feed_detail` (per-note likes/saves/comments), `list_notifications` (feeds persona)
  - What is still missing is only the per-note `exit_view2s_rate / finish5s_rate / play60s_count` (requires manually opening that note's detail page and taking a screenshot; the endpoint is located, can be wired up later)
- **Snapshot cadence**: **T+24h / T+3d** after each publish (aligned with the rubric's T+3d retro window); T+7d is added only when a long tail needs observing, not by default
- **When the exact point is unavailable (backend aggregation lags about 1 day)**: use the closest actual point within that window and state the `basis` in the entry's `notes` (e.g. `actual T+26h10m`). **Values from different points must not be used to compare rates** (exp10/11 invalidated an A/B comparison this way)
- **Pull frequency <= 2 times/day**: one run per day in the maintenance segment is enough; no extra pulls
- Run `check_login_status` before collecting; if `latest.json` is missing or `pulled_at` is older than 30h, the maintenance segment runs pull first. If the session expires -> mark that goal blocked and raise an alert; **never auto re-login**
- After collecting, write back the corresponding fields in `log.md` + append one line to `.cheat-cache/usage.jsonl`: `{"event":"perf_snapshot",...}`

### 9.2 Heartbeat and backlog (autonomous main loop, improvement 2)

- **Carrier**: a Trae-side Schedule task, once per day at **20:30** (changed from 10:30 on 2026-10-27); when two goals fall on the same day, Trae schedules an extra run manually (no automatic overtime logic)
- **Wake-up action (reworked 2026-10-27)**: run `tools\pipeline\heartbeat.ps1` -- spawned by Schedule in the foreground (outside the sandbox) via WMI: `([wmiclass]'Win32_Process').Create('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "<repo-root>\tools\pipeline\heartbeat.ps1"')`. WMI is chosen over `Start-Process` because the spawned process hangs under WmiPrvSE and is not reclaimed with the Trae session's process tree. The script itself completes PATH completion / model resolution / `CODEBUDDY_CONFIG_DIR` injection / briefing "execute heartbeat", and writes the CLI's merged stdout+stderr to `cache\heartbeat\YYYYMMDD-HHMMSS.log` (a start line + an `exit=` line)
  - **Do not launch `codebuddy` directly with `run_in_background=true`**: in that mode the sandbox whitelist does not take effect and the CLI crashes on startup (`EPERM` -> exit code `0xC0000409`, measured 2026-10-27); the failure looks like the log stopping at `First raw chunk received`
  - **How to verify**: check that the newest log has `heartbeat end ... exit=0`, then check that the backlog changed as expected; a start line with no end line = interrupted, and must not be treated as executed
  - The model is resolved by the launcher per `-Stage writing` and passed explicitly; when a goal carries its own `"model"` field, the CLI still honors it inside the session
- **Model routing (added 2026-10-17, zero-top-up principle)**: the model is specified by the **launcher** (Trae / human) on the command (`codebuddy -p -y --model <id>`); the CLI session never switches by itself. Pick a tier by step, free first, upgrading to a low-cost tier only when quality falls short:
  | Step | First choice | Credit multiplier |
  |---|---|---|
  | Lightest tasks that are least likely to go wrong and use no disk (maintenance segment: login check / due snapshot collection / retro due check / bump counting; backlog status transitions; publish registration; plain-text rewrites of ledgers and docs) -- **criterion: read-only checks or plain-text rewrites that produce no disk-consuming artifacts such as finished video / audio / cover image** | `hy3` / `hy4-preview-f` / `step-5-preview` (free pool, probe order from switch-free-model.ps1) | x0.00 |
  | **Other tasks not covered by the row above** (non-visual: script / narration script / prediction files / retro / remaining mechanical steps etc.) | `deepseek-v4.1-flash` (the best general-purpose model in practice) | x0.11 |
  | Chapter visual code / graphics / cover-image work | `glm-5.3-flash` (in practice good for graphics-heavy video and the cheapest usable tier) | x0.06 |
  A goal entry may carry a `"model"` field to override the default routing; with no such field, pick the tier by step per the table above.
  - **Resolution script (reworked 2026-10-17)**: `switch-free-model.ps1 -Stage mechanical|writing|vision [-ResolveOnly]` -- returns the candidate chain per the table (step first choice + free-pool fallback) and probes each tier for availability (non-429). With `-ResolveOnly` it only prints `MODEL=<id>` for the launcher to compose `--model`, without changing the CLI default; without it, it switches the CLI default model to the resolved result. Without `-Stage` it keeps the old behavior (keep the current model if it works, otherwise scan the free pool)
- **Circuit breaker**: `"halt": true` at the top level of backlog.json -> the heartbeat skips immediately without burning tokens; after 2 consecutive abnormal session exits Trae sets halt
- **Two granularities per session** (goal boundary = audit boundary):
  1. Maintenance segment (mandatory, idempotent, minutes): login check -> due snapshot collection -> retro due check -> bump counting
  2. Goal segment (**at most 1 goal**): pick one by priority to-publish > production > topic-selection; publish-type goals must pass the validator gate first
- **backlog.json permission model**:
  - Human/Trae exclusive writes: new `type:"goal"` entries (content goals), the `halt` switch, `publish` field values, `model` field values (see model routing above)
  - CLI may write: status transitions (pending->in_progress->done/blocked/awaiting_publish), due maintenance entries derived on schedule (retro/snapshot/bump_check), usage.jsonl
  - CLI **may not**: add content goals, change publish authorization, delete entries
- **Publish authorization granularity**: goal entries carry `"publish": "confirm"|"auto"`. **Startup phase is always confirm** (stop at the publish gate, set awaiting_publish, and wait for a human to say "publish"); after 5 consecutive posts with zero anomalies across the full flow, the user reconsiders auto (full hands-off)
- **Goal line field**: goal entries carry `"line": "series-skill-daily"|"series-cs188"|"regular"`, which decides the cheat integration depth (see the tiered integration in 8.1; when absent, treat it as regular full run)
- **Goal directory field (added 2026-10-27)**: goal entries carry `"project_dir": "videos\<episode>"` as the only locator for `check.ps1 -ProjectDir`, `design-intent.md` and `script-selfcheck.md`; **when this field is missing the CLI must not guess the directory** and must return it as blocked. Historical goals (ep03 / ep04 / ep09 / the exp series) lack this field and are not retrofitted
- **Publish timestamp field semantics (2026-10-27)**: `last_published_at` in `.cheat-state.json` **records the regular line only**; the experiment line records `last_publish_any_at` separately (currently 10-26T18:24 for exp11). The validator's "posts today / 2h spacing" still follows the actual publish records in `log.md`, not the state file
- **validator gate** (`tools\gate\validate.ps1`, mandatory before publishing, any failure blocks publishing + alerts): posts today <= 2, >= 2h since the previous post, title <= 20 characters, 3-6 tags, the prediction file exists and the "## Prediction" section matches the hash lock, **cover optional** (only validated at 1080x1440 when `-CoverPath` is passed; omit it when no cover is set and a GATE-WARN is printed), the finished video exists, **audio hard check** (video notes only: true loudness `loudnorm` I in -30..-14 LUFS and true peak <= -1.0 dBTP; **the `volumedetect` mean is forbidden** -- it counts silence into the mean, so narration with pauses is misjudged as out of range; I < -20 only warns, does not block)

### 9.3 SOP evolution (playbook proposals, improvement 3)

- After hitting a pitfall in a retro or in production, the CLI **appends** a proposal to `playbook_proposals.md` (fixed four parts: problem / evidence / proposed change / affected files); append only, never modify or delete
- Merge authority belongs to the human + Trae: review proposals periodically, merge the best into WORKFLOW/CODEBUDDY, and mark each proposal line as merged/rejected after review
- Off-limits: guardrail files (the red-line sections of CODEBUDDY.md/WORKFLOW.md/account.md/log.md) and official bumps of RUBRIC.md cannot be changed directly by the CLI; in this environment a bump's "cross-model independent audit" is downgraded to a Trae review, and the file must state this honestly

### 9.4 Launch status and acceptance

- [x] 9.1 data collection protocol + hash lock (frozen 2026-10-12)
- [x] 9.2 backlog.json + validator + CODEBUDDY.md guardrail rewrite + Schedule heartbeat (launched 2026-10-12)
- [x] 9.3 playbook_proposals.md created
- [x] First real heartbeat run (2026-10-13 10:48, collection completed; maintenance segment idempotent, no out-of-scope writes)
- [x] First automatic data collection (2026-10-13 backfilled ep01/ep02 baselines + ep02 24h point)
- [x] First real retro run (2026-10-14 ep01, including hash-lock verification)
- [x] Automated data source integration (2026-10-27: `tools/metrics` replaces manual screenshots, see section 4.6 / 9.1)
- [x] Rubric axis change v1-retention (2026-10-27, calibration pool reset to zero)
- [ ] 5 posts with zero anomalies -> user discusses auto (currently 0/5, v1 restarts the count)


