# Examples walkthrough

**English** | [中文版](README.zh-CN.md)

This is the complete text asset set of one **actually published** Xiaohongshu video, "Same question, why does AI answer differently every time" (`ep11-sampling/`), plus 5 frames sampled from the finished video (`shots/`).

It exists not so you can copy the copy, but so you can see clearly **what each step should produce and what it should check**.

---

## At a glance: where the files sit in the pipeline

```
article.md ──▶ facts.md ──▶ script.md ──▶ outline.md ──▶ beats.json
                   │            │             │
                   │            └──▶ script-selfcheck.md (gate evidence)
                   └──▶ design-intent.md (the three questions before authoring)

                   everything above must pass check.ps1 -Gate pre-code before web development starts
```

| File | Stage | What question it answers | What to look at when imitating |
|---|---|---|---|
| [`article.md`](ep11-sampling/article.md) | Phase 0 input | What the raw material says | Material length and information density; this is "raw material", not "a finished script" |
| [`facts.md`](ep11-sampling/facts.md) | Phase 0 output | Which facts can be told, where they come from, how to tell them without misleading | **The cross relations in the source list**, scope boundaries, the 6 teaching-design items, the argument chain |
| [`design-intent.md`](ep11-sampling/design-intent.md) | Before authoring | Which metric this piece moves, who it references, which lesson it avoids | Whether the three questions carry **this episode's concrete numbers**, not slogans |
| [`script.md`](ep11-sampling/script.md) | Phase 1 | Every sentence the viewer hears | `---` beat split = one screen = one audio segment; paragraph form, not subtitle form |
| [`outline.md`](ep11-sampling/outline.md) | Phase 1 | What appears on screen for each beat | Each step's `elements:`, transition, visual focus, reading-protection duration |
| [`script-selfcheck.md`](ep11-sampling/script-selfcheck.md) | Phase 1 gate | Did the script pass the self-check | Pass/fail per four-layer item + evidence; the opening three elements; the blind-read original text |
| [`beats.json`](ep11-sampling/beats.json) | Phase 1 output | The millisecond-level layout plan for each beat | Note that `dur_ms` is an **estimate**; after production `raw-vertical/marks.json` governs |

---

## Three "transferable" points in this example

### 1. Sources must cross, and the boundaries must be written down

In `facts.md` every key conclusion has at least two independent sources, and it states explicitly "what may not be said":

- The temperature ranges differ across implementations (0–2 / 0–1), so the narration only says "low / high / 0" and never quotes a specific range
- 80 results out of 1000 is **an experiment others ran on their own inference stack**, and may not be stated as "all models behave this way"

This is what "do not mislead" looks like in practice; it beats any reminder to "please pay attention to accuracy".

### 2. Every step in the outline has a screen element

Every step in `outline.md` has an `elements:` field, picked from the skill's viz element library (chat bubbles / loop arrow / data bars / timeline…). **A step you cannot write an element for means that screen will be empty**, and it should be fixed while writing the outline rather than discovered at the development stage.

### 3. The self-check must leave evidence, not checkmarks

Every row of `script-selfcheck.md` is "verdict + evidence + what changed", e.g. "opening three elements: who PASS / what PASS / why worth watching MISSING → added one line in beat 2 about what this has to do with you". A PASS without evidence means nothing was checked.

---

## Time points the screenshots correspond to

| File | Finished-video time | Screen |
|---|---|---|
| `shots/01-hook.png` | 0.6s | One question, three different answers, and the third conclusion is the opposite |
| `shots/02-sampling.png` | 12s | Loop arrow + "rolling dice", giving "sampling" a name |
| `shots/03-probability.png` | 30s | "The weather today is really" → the probability table for the next word |
| `shots/04-top-p.png` | 80s | top-p: keep only the candidates covering the top 90% cumulative probability |
| `shots/05-ending.png` | 150s | Calling back to the opening hook: the choice is yours |

The screenshots come from the finished video, not design mockups — so they also serve as a reference for "does the screen density meet the bar": every screen has a main visual, none is a pure text page.

---

## How to use this example

1. **Do not copy the copy**. Replace the topic, sentences and metaphors with your own.
2. Copy the empty skeleton from `../templates/episode/` into your `videos/<episode>/`, then fill it following this example's structure.
3. After filling in `facts.md`, run `check.ps1 -Gate pre-script` first; after filling in `script.md` + `outline.md` + `script-selfcheck.md`, run `-Gate pre-code`.
4. To verify the tools themselves work, you can run them directly against this example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 `
  -ProjectDir examples\ep11-sampling -Gate pre-code
```

Expected exit code `0` (C13 for `design-intent.md` only issues a WARN and does not block).

> The data in this directory comes from the author's account and is used only to illustrate the method; copyright in the cited sources belongs to their original authors.
