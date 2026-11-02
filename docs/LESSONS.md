# LESSONS.md — hard lessons from published samples

> This file is part of xhs-video-agent; sample data comes from the author's account and is used only to illustrate the method.
>
> Append one line at the end of every retro; **read this before starting any episode**.
> Write only "what the next episode can change", not reflections. A single-episode observation goes under "To verify"; only ≥2 notes in the same direction get promoted to "Verified".
> Last updated: 2026-10-30 (n=11, including the experimental line exp10/exp11; data source `data/metrics/latest.json` pulled 2026-10-30T12:32Z)

---

## Verified (≥2 notes in the same direction, usable as constraints)

1. **The five notes under 5s average watch all stalled at 139–674 impressions; the two over 15s both got 1300+.**
   Retention is the gate, not the result. Before editing, ask "can this line hold someone".
2. **CTR runs opposite to impressions**: the higher the impressions, the lower the CTR (2.9% vs 7.3%).
   The cover image is gone (first frame is the cover image since 2026-10-27), so CTR now has only two variables — title + first frame. Stop hoping that "changing the cover" will rescue the numbers.
3. **Two posts on the same day differed by 2.5x impressions and 6x retention** (10-10, 1350 vs 526, 18s vs 3s).
   Same time slot, same duration; the difference was in the opening and the delivery, not in account status.
4. **"Giving a checklist" pulls clicks but does not hold retention**: three tool-checklist posts had CTR 5.9% / 7.3% / 5.4% and still 3–4s retention.
   Something to take ≠ willing to watch to the end; a checklist needs a throughline of "why you should hear me out".

## To verify (single note, do not treat as a pattern)

5. Changing the opening does work, but not enough: 2-second exits 81.8% → 66.3%, 5-second completion 12.9% → 16% (ep09 → exp11).
   Next test: "first frame gives the result vs first frame gives the question", comparing only the 2-second exit rate.
6. **A 60-second telegraphic style is audible but not understandable** (ep10, 2026-10-30): 8 beats, 8 concluding sentences, metaphors ahead of facts, code names (svc-telemetry / 2.1.313) with no explanation; blind prediction composite 9.29 but the user could not restate it.
   Next episode: the first beat lands "who gets hit" first, metaphors must come after the noun, and at least one causal connective every 2–3 beats.

## Rejected (stop using these as explanations)

7. **"A new account gets a cold-start traffic package"** — two posts on the same day differed by 2.5x; a single post on 10-25 pulled account impressions back to 292, so the account was not de-weighted.
8. **"Missing tags / cover image broke distribution"** — ep09 had tags and a cover image and got 127 impressions; the reverse does not hold.

---

## Three actions for the next episode (rolling, max 3)

1. First beat gives the result: a number / a finished artifact / a failure screen, no background; but **inside the first beat you must name "who gets hit"** (e.g. "Cursor users who installed the Claude Code extension"), not just a metaphor.
2. Finish within 2 minutes (120–150s is best); one information point every 12–15 seconds, and "because / so" between beats.
3. The ending gives an action the viewer can do today and calls back to the opening; the action must be **pointable** (a specific repo / project page / command line), not a generic tool name — `exp10/11` proved that "a checklist you cannot take away" only buys clicks, not saves.

---

## Retro append (2026-10-30)

- 2026-10-30 · exp11 · what the prediction got right is "impressions > group A" (1.41x, inside the bet range) and "likes+saves ≥3" (4); what it got wrong is "saves ≥ likes" (1 < 3) → next episode: give "pointable, take-away" specific repos / project pages (not generic tool names), then saves will move; a checklist the reader cannot take away only buys clicks, not saves
- 2026-10-30 · exp10 · what the prediction got right is "impressions < group B" and "likes+saves ≤2" (actual 0); what it got wrong is treating QL as the main driver of saves (the QL2 and QL4 posts both had 0 saves) → next episode: judge "worth saving" only by whether there is a pointable artifact, not by how many quotable lines there are

---

## Measurement corrections (2026-10-30, tightened after the retro)

- To-verify item 5 can only be read as a **local conclusion about "the first 5 seconds"** and must not be extrapolated to retention improvement: exp11's 2-second exits at 66.3% and 5-second completion at 16% are both better than ep09 (81.8% / 12.9%), yet average watch was only **4s** (ep09 was 12.1s) — viewers kept dropping off fast after the 5-second mark.
- "24h cap" holds only for **reads and engagement**, **not impressions**: B′ reads went 133→134 (+1) while impressions went 259→433 (+67%) over the same period. Impression growth in the following 3 days is not a heat signal.

---

## Retro append format (one line + one action)

```
- 2026-10-27 · <ep> · prediction got right <dimension> (because…), got wrong <dimension> (because…) → next episode action: <one executable sentence>
```
