# Workflow quick reference (cheat-on-content)

**English** | [中文版](CHEAT-WORKFLOW.zh-CN.md)

> This file is part of xhs-video-agent; sample data comes from the author's account and is used only to illustrate the method.
>
> This is the quick-reference doc `/cheat-init` creates at your project root. The full spec lives in cheat-on-content's `SKILL.md` and `shared-references/`.
> Use this file when you "forgot what to say next" — you do not need to read it from top to bottom.

---

## The process in one line

```
Find a topic
  ├─ No publishing history → /cheat-seed brainstorm (interest × trending)
  └─ Has history          → /cheat-seed brainstorm (interest × trending × what you have done before)
                            (both run cheat-seed; the difference is the extra history context when you have published)
  ↓
cheat-seed writes 5 drafts to → scripts/<date>_<id>_<short>.md
  ↓
The user rewrites scripts/<date>_<id>_<short>.md (overwriting the same file)
  ↓
/cheat-score scripts/<date>_<id>_<short>.md → see the rubric score (exploration)
  ↓
/cheat-predict scripts/<date>_<id>_<short>.md → write immutable prediction v1 to predictions/
  ↓
After shooting → /cheat-shoot scripts/<date>_<id>_<short>.md
   ├─ Create the videos/<date>_<id>_<short>/ directory
   ├─ Ask the user: "Is the script you actually used when shooting the same as scripts/<id>.md?"
   │   ├─ Same → cp → videos/<id>/script.md, keep prediction v1
   │   ├─ Changed → ask for the final script → compute the diff
   │   │   ├─ diff ≥30% → auto /cheat-predict — mode: v2 → predictions/<id>.md append a `## Prediction v2` section
   │   │   └─ diff <30% → ask whether to write v2; default is to keep v1
   │   └─ Major rewrite → go through the _redo flow (new scripts/<id>_redo.md + re-run cheat-predict)
   └─ buffer +1
  ↓
Publish → /cheat-publish + URL → buffer -1
  ↓
T+3 days → /cheat-retro videos/<date>_<id>_<short>/
   ├─ Pull data / user pastes it → write videos/<id>/report.md
   ├─ Append a ## Retro section to predictions/<id>.md
   ├─ diff scripts/<id>.md vs videos/<id>/script.md → learn the user's editing patterns
   └─ Write new observations into rubric-memo.md / SCRIPT-PATTERNS.md (actual results go only into rubric-memo, never into RUBRIC.md)
  ↓
≥3 deviations in the same direction → /cheat-bump (upgrade the rubric)
```

---

## Five stages and their trigger phrases

### ① Topic stage

| What you want to do | Trigger phrase |
|---|---|
| See the ranked recommendations in candidates.md | "recommend topics" / "what's next" |
| Pull today's trending topics to extend candidates | "pull trends" / "what can I make today" |
| See the current state | "status" |

> Having no candidates.md during cold-start is the default state — do not conclude the tool is broken because of it.

### ② Scoring + prediction

| What you want to do | Trigger phrase | Writes files? |
|---|---|---|
| See a script's rubric score (exploration) | "score this path/to/draft.md" | No |
| Write a formal immutable prediction log for the final script | "start prediction" or "start prediction for this script path/to/draft.md" | Yes (`predictions/...md`) |

> **Core difference between score and predict**:
> - score is exploration, side-effect free, safe to run repeatedly
> - predict is a commitment: once written, the `## Prediction v1` (or `## Prediction v2`) section is locked by the hook

> **v2 re-prediction trigger**: when cheat-shoot detects a line-diff ≥30% between the shooting script and the original scripts, it calls cheat-predict automatically to write a `## Prediction v2` section (append, does not overwrite v1). See the v1/v2 section convention in [shared-references/prediction-anatomy.md](../shared-references/prediction-anatomy.md).

### ③ Publish registration

Right after publishing:

```
"published https://..."
```

or:

```
"published predictions/2026-05-04_xxx.md link is https://..."
```

This updates `published_at` / `Platform` / `URL` in the prediction file header and adds the file to the `pending_retros` queue.

### ④ Retro

T+3 days (default):

```
"retro predictions/2026-05-04_xxx.md"
```

or simply:

```
"retro"
```

The latter takes the earliest entry from `pending_retros`.

> A retro needs data from you. The default is manual paste — paste "plays / likes / comments / shares" and the top 20 comments into the conversation.
> With an adapter configured, cheat-retro can pull them automatically.

### ⑤ Rubric upgrade (rare)

**Only propose when the conditions are met**:
- Calibration pool ≥ 5 posts
- ≥ 3 new calibrations since the last bump
- ≥ 3 consecutive deviations in the same direction detected

If met, run:

```
"upgrade rubric --propose 'ER weight 1.5→2.0, add an MS dimension'"
```

bump is a high-risk operation — it runs 5 validation steps (including an independent cross-model review). See `cheat-on-content/shared-references/bump-validation-protocol.md`.

---

## Three non-negotiable principles

> Violate any one of these and the whole calibration loop degenerates into astrology.

1. **Blind prediction**: the prediction section is written before seeing any data and cannot be changed afterwards. The hook enforces this at the harness layer.
2. **Upgrade = full rescore**: a bump must rescore the entire calibration pool + get an independent cross-model review.
3. **The rubric is a workbench, not a museum**: observations that were absorbed or overturned get deleted. git history is the archive.

---

## Default configuration

Defaults for a project created by `/cheat-init`:

| Setting | Default | When to change |
|---|---|---|
| `RETRO_WINDOW_DAYS` | 3 | Set 7 for long-form / slow platforms |
| `BLIND_CHECK` | strict | Temporarily lenient for drills / tests |
| `MIN_SAMPLES_FOR_BUMP` | 5 | Do not lower it |
| `CROSS_MODEL_AUDIT` | true (if mcp__llm-chat__chat is configured) | false only when offline |
| `TREND_SOURCES` | ["manual-paste"] | Add new sources via `enabled_trend_sources` |
| `POOL_PATH` | candidates.md | Change the field when using Notion |

---

## Dashboard (status command)

Say "status" at any time and it outputs:
- Current mode / rubric version / calibration sample count
- To-dos (pending retros + same-direction deviation warnings + stale in-progress)
- Candidate pool size + days since the last trend pull
- Health (RUBRIC.md line count / whether hooks are installed / whether cross-model review is configured)
- Suggested next steps (in recommended priority order)

---

## File structure (your project root)

```
<your-content-project>/
├── docs/RUBRIC.md           # Single source of truth for scoring rules (currently v1-retention, five dimensions)
├── docs/LESSONS.md          # Hard lessons appended at every retro (must-read before each episode)
├── docs/SCRIPT-PATTERNS.md  # Writing pattern library
├── WORKFLOW.md              # This file
├── STATUS.md                # Dashboard (maintained by cheat-status)
├── candidates.md            # Candidate pool (optional; written by cheat-seed / cheat-trends)
├── .cheat-state.json        # State file (git tracked)
├── .cheat-cache/            # Local cache (gitignored)
│   ├── usage.jsonl
│   └── trends-history.jsonl
├── .cheat-secrets.json      # API key / cookie (gitignored)
├── .cheat-hooks/            # Copies of hook scripts
│   ├── prediction-immutability.sh
│   ├── session-start.sh
│   └── log-event.sh
├── .claude/settings.json    # Contains cheat-on-content hooks
│
├── scripts/                 # **All drafts before shooting**
│   └── YYYY-MM-DD_<id>_<short>.md   # written by cheat-seed or by the user
│
├── predictions/             # **Immutable prediction log** (hook-protected)
│   └── YYYY-MM-DD_<id>_<short>.md   # written by cheat-predict
│
└── videos/                  # **Created only after shooting** (by cheat-shoot)
    └── YYYY-MM-DD_<id>_<short>/
        ├── script.md        # The final shooting script you provide
        └── report.md        # T+3d data (written by cheat-retro)
```

### How the three directories relate

| Directory | Stage | Content | Written by |
|---|---|---|---|
| `scripts/` | Drafts before shooting | Claude AI draft or user original | cheat-seed writes the first version; user edits stay in the same file |
| `predictions/` | Prediction locked | 7-component immutable log | cheat-predict |
| `videos/<id>/` | Post-shoot artifacts | Final shooting script + T+3d data | cheat-shoot creates the directory; cheat-retro writes report.md |

All three use the same `<date>_<id>_<short>` naming; `<id>` is the first 12 characters of the sha256 of the first content written to `scripts/<id>.md` and **does not change when the draft is rewritten**.

`/cheat-init` creates the skeleton above automatically (without overwriting anything that exists).

---

## Stuck?

- Read the "requests you must refuse" section of `cheat-on-content/SKILL.md` — what you want to do may be exactly what it is designed to refuse
- Read the matching sub-skill's `cheat-on-content/skills/cheat-X/SKILL.md`
- Run "status" and look at cheat-status's "suggested next steps"
