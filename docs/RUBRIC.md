# RUBRIC.md — v1-retention · 2026-10-27

> This file is part of xhs-video-agent; sample data comes from the author's account and is used only to illustrate the method.
>
> **This version is a re-axis, not a re-weighting**: the objective function moved from "guess impressions" to "guess average watch seconds per viewer".
> Basis: full backstage data for 9 notes (`data/metrics/latest.json`, pulled 2026-10-27) plus the structural conclusions in `cache/bump-20261024-draft.md`
> (the seven v0 dimensions ranked in the opposite direction, and there were 6 dominance violations — no non-negative weighting can fix them).
> The v0 scoring archive (ep01–ep09, exp10/11) is kept as history and **must not be compared with scores from this version**; `calibration_samples` was reset to zero, so v1 starts accumulating from 0.

---

## Objective function (read this first)

A script's value is judged in this order:

1. **Average watch seconds per viewer** (primary) — decides whether the platform keeps pushing it. The account's current median is 9s: the two notes above 15s both got 1300+ impressions; the five below 5s all stalled at 139–674.
2. **Click-through rate** (secondary) — a matter of title + first frame (this account has not set a cover image since 2026-10-27; the first frame is the cover image), and it is no longer the bottleneck (5.4%, above the norm for accounts in this niche).
3. **Follower growth** (last) — happens only when "this person is useful" turns into "I want to see the next one".

Impressions are not the goal, they are the result of the three above. **Do not edit the script for impressions; edit it so people keep watching.**

---

## Formula

```
composite = (HO×2 + PE×2 + TK×1.5 + NA×1 + QL×0.5) / 7 × 2.0
```

Five dimensions, integer scores 0–5; weights sum to 7, composite is 0–10.

The weights are a **prior, not a fit**: the 9 samples have no per-note dimension scores, so any "regression fit" is self-deception. Each retro corrects it with one deviation; change the formula only after 3 consecutive notes deviate in the same direction.

---

## The five dimensions

### HO — Hook & Hold (×2)
*In the first 3 seconds, can you stop the scroll? In the first 10 seconds, can you open a gap of "I need to know why"?*

- **0** — greeting, background setup, "AI is hot lately"
- **3** — clear promise, but it takes one sentence of setup before the body starts
- **5** — the first sentence is a concrete result / failure shot / counter-intuitive number; the information gap is built within 3 seconds

Anchors: 5 = a first line like "AI does my work, and gets it half right once" that carries its own question; 0 = "Hi everyone, today we'll talk about…".

### PE — Payoff Density (×2)
*How much usable information per unit of time? At which second does the hardest point of this piece land?*

- **0** — one point repeated, setup the whole way
- **3** — the information is right, but about a third of the time is setup / transitions
- **5** — a new information point every 8–10 seconds on average, and the first hard point arrives within the first 5 seconds

Note: PE is not "a lot of information", it is "information arriving early and continuously". Stuff it with jargon but reach no conclusion in the first 30 seconds and PE can only be 2.

### TK — Transferability (×1.5)
*That same day, can a viewer open / copy / imitate one concrete thing?*

- **0** — pure concepts, nothing pointable
- **3** — names a concrete project or tool, but the viewer still has to search and decide how to use it
- **5** — gives a project page you can open directly, a command you can run directly, or a checklist you can follow as-is

**The requirement is not "the script contains a code block", it is "there is something pointable"** — v0's QL conflated the two, which is why tool roundups scored lowest.

### NA — One Line (×1)
*Can the whole piece be compressed into one repeatable sentence? Do the sections build on each other or just sit side by side?*

- **0** — a list of points, order shuffled with no effect
- **3** — there is a throughline, but 3+ points sit side by side in the middle
- **5** — one sentence can restate it; every section answers the question the previous section left open

### QL — Quotable (×0.5)
*Are there 1–2 lines that stand on their own outside the video?*

- **0** — all narration
- **3** — only the closing line
- **5** — at least two lines stand alone, spread across the head / middle / end

The low weight is because the evidence is weak (across this account's 9 notes, quote density did not track ranking). **Never sacrifice PE for a quotable line.**

---

## Hard constraints (not scored; fix or explain in writing when hit)

- **Duration 120–180s, with 150–180s as the target band** (raised on 2026-10-31: 120s was judged as "used up before the point lands", so the narration script was relaxed to 560–680 characters accordingly); **>180s must justify itself in `design-intent.md`** (you pay the completion-rate price). <120s counts as not using the target band, and needs a reason for not expanding.
- **The first beat must not be a greeting / background / "AI is hot lately"**.
- **The ending gives one action the viewer can do today, and calls back to the opening hook**.

> **This paragraph is not a content rule**: how to explain clearly (land the metaphor first, causal connectives, layered terminology) is governed by the four-layer self-check in `skills\web-video-presentation\references\SCRIPT-STYLE.md`; this file makes no mechanical assertions about content hooks or information-point density. On 2026-10-31 the two rules added on 10-30 were withdrawn ("the first beat must name who gets hit" and "one information point every 12–15 seconds"): they produced label-style fake compliance (named in the narration, not on screen) and overrode the script self-check.

---

## Prediction buckets (absolute scale: views, against this account's current distribution)

| Bucket | Range | Prior probability |
|---|---|---|
| Bottom | < 89 | 25% |
| Base | 89 – 133 | 25% |
| Hit | 133 – 249 | 25% |
| Breakout | 249 – 500 | 20% |
| Outlier | > 500 | 5% |

The boundaries come from P25/P50/P75 of the 9 notes; **recompute every +3 samples**. A prediction must give "most likely bucket + central value + probability of every bucket", summing to 100%.

---

## Three questions before starting any episode (write them in `videos/<ep>/design-intent.md`)

Free text, no forms, no template. The three questions must be answered with this episode's concrete numbers and concrete script; if you can't write it, stop and ask a person:

1. **Which metric does this episode move, and to what target number** (taken from the distribution in `latest.json`, no wishful thinking).
2. **Which of your own episodes is the reference**, why it is comparable (same format / same duration / same audience), and what it got right.
3. **Which entry in `LESSONS.md` this episode avoids**, and what the concrete action is.

---

## Scoring discipline

- **Blind scoring**: before scoring, do not look at the anchors, `data/metrics`, or the retro section of `predictions`.
- **30 seconds per dimension**, trust the first integer; if 3/4 keeps flipping, write 3 + a note.
- Every score must be backed by **one concrete line from the script** as evidence, otherwise lower that dimension's confidence.
- Self-scores do not replace the blind sub-agent's score; when they differ by ≥2 points, state where in the prediction file.

---

## Known limitations

- 9 notes, no per-note dimension scores, v1 weights untested; only one note has a complete retention curve.
- Retention is partly outside the script's control (first frame, voice, pacing, which audience pool the platform assigns).
- Click-through rate is mainly decided by **title + first frame** and correlates weakly with the script — **do not attribute CTR swings to the script**.

---

## Version and rollback

- v0 (tutorial-builder's seven equal-weighted dimensions) has been superseded by this version; the original v0 text is the copy source at init time, `skills/cheat-on-content/starter-rubrics/tutorial-builder-zero.md` (this project is not a git repo, so there is no commit history to roll back to).
- Rollback: copy that starter file back to `RUBRIC.md`, set `rubric_version` in `.cheat-state.json` back to `v0`, and restore `calibration_samples` to 5.
- If ranking agreement is still < 0.8 after v1 has run 3 episodes: **stop tuning weights**, switch to keeping format notes on "which content formats work on this account", downgrade the rubric to a check list, and leave prediction to the historical distribution in `data/metrics`.
