# design-intent · reg-ep11-2min

**Topic**: Why does AI give a different answer to the same question every time (sampling / temperature / top-p / temperature 0 is still unstable)

## 1. Which metric should this move, and what's the target number?

Move **average watch seconds per viewer**. In `data/metrics/latest.json` (captured 2026-10-31T04:51Z), the `avg_watch_s` ranking across nine videos is 4 / 4 / 4 / 8 / 9 / 12 / 18 / 30 / 87 — median **9s**, upper quartile **18s**. This video targets **≥15s**, with a floor of **12s** (= ep09, this account's best long-form video).

That number isn't a wish: the two videos on the account with average watch time >15s both have impressions above 1300 (1421 / 1416), while all five under 5s sit at 139–674. Retention is the gate; hit 15s first, then impressions are worth discussing.

On the read side, no new target: keep the hit bucket 133–249 with a midpoint of **150** (median `reads` across 9 videos: 134).

## 2. Which of my own videos to reference, and why it's comparable

Main reference: **ep09, "AI does the work for you, but only gets half of it right"** (2'58", average 12s, reads 27, impressions 151). The reason it's comparable is that the form is the closest: also a mechanism explanation with one main thread, also over 2 minutes, also zero prior knowledge viewers. What it got right: **every beat answers the question the previous beat left behind** (why does it only get half right → because it only did planning → why isn't planning enough → because no one validates at execution time), so even with only 27 reads, average watch time still reached 12s — the people who stayed were pulled by the causal chain, not buried by information volume.

What it got wrong: **the ending gave nothing to take away** — it only offered a principle like "do it in three steps," no number or command you could type the same day. This video fills that gap — the two concrete temperature values (0–0.2 / 0.8 and above) are that "pointable object."

Secondary reference: **ep01, "the least painful vibe coding skill"** (average 30s, the account's best). Borrow exactly one thing: the first sentence gives the result directly, with no setup.

## 3. Which cheat-lessons item does this avoid?

Avoid **item 6** (the 60-second telegram style = audible but unintelligible; the ep10 lesson: metaphors before facts, code names with no explanation). Concrete actions in this video:

- Every term **gets the everyday action first, the name second** — first "roll a die for every word it says," then "this operation is called sampling"; first "make this table sharp or flatten it," then "this knob is called temperature"; first "cut off the long tail," then "it's called top-p." The order never reverses.
- Visuals hang the matching object on the same beat: probability bars sharpening and flattening with temperature, other people's requests crowding into the batching queue, the divergence point of the 1000-run experiment. **Never rely on the narration naming it alone** (the root of ep10's false pass).

At the same time, avoid **item 4** (lists don't hold retention): the whole video has only one claim — "it makes a legal choice at every step, so you have to take the choice back" — and the two temperature tiers at the end aren't a parallel list, they're two corollaries of the same claim.

## 4. Duration rationale

Target band 150–180s. Back-calculating from this account's measured speaking rate of 4.48 characters/second (ep10: 210 characters / 46.9s), the narration needs **670–800 characters**; this video's 13 beats are written at around 690 characters, and GAP is calibrated with an actual ffprobe measurement after rendering. Don't deliberately exceed 180s.
