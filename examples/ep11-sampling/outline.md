# outline.md · Shot Outline (ep11 · 5 chapters, 13 steps · 2-minute format)

**English** | [中文版](outline.zh-CN.md)

> Portrait 1080×1440 (`--ratio=3:4`), theme `warm-keynote` (warm beige background `#f5efe1` / ink-brown text `#43302b` / teal accent `#14b8a6`).
> Structure: **hook 2 beats → mechanism 2 beats → two knobs 3 beats → twist 4 beats → landing 2 beats** (13 beats == script.md beat count == narrations.ts total).
> Layout uses `.stage-3band` throughout: `band-top` hook line / `band-main` key visual ≥55% / `band-foot` caption line (**with source annotation**).
> **First frame is the cover** (this account stopped using separate covers from 2026-10-27): beat 1 carries the big title "Three answers, three versions" + three different AI answers on one screen.
> Transitions: within a chapter, "redraw content in the same window" (110ms final state); across chapters, "shift everything up 20px + fade in."
> `beats.json` is the layout-plan version (timing estimated at 4.4 characters/second); after rendering, use `raw\marks.json` as the time reference.
> Every step must carry ≥1 concrete `components/viz` element; wide, flat elements don't stand alone on a 3:4 stage (`BarChart` / `TimelineRail` / `CardGrid` each pair with a custom visualization filling the middle).

## 01 · Hook: three answers (hook) | 2 steps

**Narrative link**: The opening gives no background, just physical evidence of the symptom — same question, three answers, and the third even reverses the conclusion. Only beat 2 names the phenomenon (sampling), breaking the default assumption that "the model is broken."

**Information pool**
- Symptom: same prompt, same model, different output across runs — facts §2 F4 (S1)
- Naming: drawing once per generated word = sampling — facts §2 F1 (S3 / S4)
- Key distinction: not "it thought wrong," but a legal choice at every step — facts §4 Argument chain

| step | Visual | Element | Transition | Visual focus | Protection |
|---|---|---|---|---|---|
| 1 | Top small text "You ask AI · the same question · three times" + big text "Three answers, three versions"; middle four chat bubbles: one question + three different answers, the third highlighted with a "conclusion reversed" corner tag; bottom "Same prompt · same model" | ChatBubbles | Bubbles drop in top to bottom, the 4th delayed 110ms and highlighted | Title → question → three answers | 1.2s |
| 2 | Top "AI isn't 'thinking'; it's rolling dice"; middle circular arrow center "Rolling dice / once per word"; bottom-right tag "This operation is called sampling" + "Your copy and code are both affected"; bottom "Sampling = draw one from a probability table and append it" | LoopArrow | Ring draws itself first, center text scales in, tags highlight after a delay | Ring → center text → tags | 1.2s |

## 02 · Mechanism: one word at a time (mech) | 2 steps

**Narrative link**: Picks up the "what table is it drawing from" left by beat 2. First draw the table (four bars), then explain why "draw, append, reread" makes one off step lead to every step off.

**Information pool**
- Mechanism: each step scores every word in the vocabulary → softmax normalizes into probabilities → draw one — facts §2 F1 (S3 / S4)
- Example distribution: "good" 60% / "not bad" just under 20% / "hot" 10% / rest 10% — facts §4 Example A
- Cumulative effect: the same token enters the context and affects all subsequent steps — facts §2 F1 (S3)

| step | Visual | Element | Transition | Visual focus | Protection |
|---|---|---|---|---|---|
| 3 | Top "How likely is each next word"; middle four vertical bars 60/18/10/12 with percentages on top; three short labels under the bars "vocabulary 50k+ / only the top four shown / the rest combined 12%"; bottom "You say: The weather today is really" | BarChart | Four bars grow in sequence (`viz-grow`), the tallest highlighted last | Bar 1 → bar 4 → tallest bar | 1.5s |
| 4 | Top "Pick one, append it, reread"; middle top: generation-order rail with 6 words (The/weather/today/is/really/…); middle bottom: hand-drawn fork — the same line splits at the 4th word into two different sentences at the ends; bottom "If the first die leans a little, the path drifts further and further" | TimelineRail + hand-drawn fork | Rail lights up left to right, fork drawn over 300ms, the two endings fade in in sequence | Rail → fork point → two endings | 1.2s |

## 03 · Two knobs (knob) | 3 steps

**Narrative link**: Picks up the already-established "table" object — since it draws from a table, there are knobs that change the table's shape. Cover temperature first (sharp/flat), then top-p (cut the tail); only after both knobs does the next chapter's "so what if you turn it all the way tight?" become inevitable.

**Information pool**
- Temperature: divides logits before softmax; <1 sharpens, >1 flattens, approaching 0 = greedy — facts §2 F2 (S4)
- Sharp table: top word ~95% — facts §4 Example B
- Flat table: top score drops to ~30%, fringe words get a chance; spoken examples "really nice / hot enough to fry an egg" — facts §4 Example B
- top-p: keep the smallest word set whose cumulative probability reaches p, truncate the long tail — facts §2 F3 (S2)
- Don't turn both at once — facts §2 F8 (S4)

| step | Visual | Element | Transition | Visual focus | Protection |
|---|---|---|---|---|---|
| 5 | Top "First knob: temperature"; middle four bars sharpen (95/3/1/1), the pointer on the vertical scale rail on the right pushed to the "low" end; bottom "Low temperature → sharp table → almost no suspense" | BarChart + hand-drawn scale rail | Bars morph from the previous beat's shape to the sharp table, pointer slides from below to the low end | Bars → pointer → "sharp" label | 1.2s |
| 6 | Top "High temperature, the table is flattened"; middle four bars flatten (30/28/22/20), two small cards below compare the two versions of the same compliment; bottom "Same compliment: this time 'really nice,' next time 'hot enough to fry an egg'" | BarChart + hand-drawn two cards | Bars morph to the flat table, the two cards fade in and highlight in sequence | Bars → card 1 → card 2 | 1.2s |
| 7 | Top "Second knob: keep only 90%"; middle eight long-tail bars, a vertical knife line sweeps past the 5th, the long tail on the right grays out and collapses; bottom "It's called top-p: cumulative to 90%, cut everything after" | BarChart + hand-drawn knife line | Knife line sweeps in from right to left, the part beyond the line grays out and sinks | Knife line → grayed tail | 1.2s |

## 04 · Twist: tight to zero, still unstable (turn) | 4 steps

**Narrative link**: Picks up the relief beat 7 gives with "so it can't improvise"; beat 8 turns temperature to zero (which, per S1, should be stable), beat 9 immediately overturns it (batching), beat 10 gives the micro-mechanism of the upset, beat 11 gives the scale of evidence. This is the retention turn of the whole video.

**Information pool**
- Official expectation for temperature 0: consistent, repeatable — facts §2 F4 (S1)
- Real cause: kernels are not batch-invariant + batch size varies with load → reduction order changes — facts §2 F5 (S3)
- Micro consequence: the last decimal flips near-tied candidates — facts §2 F5 (S3 / S4)
- Scale: 1000 greedy runs → 80 unique results, first 102 tokens identical, divergence at 103 — facts §2 F6 (S3)

| step | Visual | Element | Transition | Visual focus | Protection |
|---|---|---|---|---|---|
| 8 | Top "Turn temperature to zero, this should be identical now"; middle three identical cards "pick the highest score" stacked vertically; bottom "The official docs say so too: for repeatability, use zero" | CardGrid (1 col × 3) | Three cards land at the same speed (deliberately "the entrance animation is identical too"), last card highlighted | Three identical cards | 1.2s |
| 9 | Top "Unstable"; middle four pipeline stages: your request / other people's requests / batched together / computed together, with 3 unfamiliar requests squeezed into the batch frame; bottom "One more person, additions split and reordered" | PipelineFlow + hand-drawn batch frame | Pipeline lights up in sequence, batch frame expands at stage 3 and squeezes in three blocks | Stage 1 → batch frame → squeezed blocks | 1.2s |
| 10 | Top "Last digit differs a little, and it flips"; middle two nearly equal bars 0.5001 / 0.4991, pointer wobbles from left to right; bottom "The word that should have been 'good' slips to 'not bad'" | BarChart + hand-drawn pointer | Two bars grow to equal height (a 0.001 difference is invisible), pointer wobbles then slides right | Two bars → pointer → landing point | 1.2s |
| 11 | Top "One thousand runs, eighty answers"; middle timeline: first 102 words same color, node 103 splits into two, rail labeled 1000 / 80 on the right; bottom "The first 102 words identical, divergence at word 103" | TimelineRail + hand-drawn fork point | Rail lights up and stops at the fork, fork line and the 80 tag fade in after a delay | Rail → fork point → 80 | 1.5s |

## 05 · Landing: two temperature tiers, one rule (fix) | 2 steps

**Narrative link**: Picks up "parameters can't save you"; the only way out is scenario-based tiers + validation. The last step callbacks the three answers from beat 1 and lifts the conclusion to "whose hands the choice is in."

**Information pool**
- For stability: temperature 0–0.2 + validation + rerun (low temperature doesn't guarantee correctness) — facts §2 F7 / F9 (S4)
- For divergence: 0.8–1.0, several candidates per request — facts §2 F7 (S4)
- Rule: tune only one of temperature and top-p — facts §2 F8 (S4)

| step | Visual | Element | Transition | Visual focus | Protection |
|---|---|---|---|---|---|
| 12 | Top "Stability isn't tuned; it's verified"; middle four cards 2×2: stability 0–0.2 / add a validation step / divergence 0.8+ / ask for ten at once; bottom "Rerun on failure, don't expect one-shot correctness" | CardGrid (2 cols × 2) | Four cards land 2×2 in sequence, cards 2 and 4 delayed 110ms | Card 1 → card 2 → card 3 → card 4 | 1.2s |
| 13 | Top big text "The temperature is its, the choice is yours"; middle three-row list: don't turn it with top-p / a legal choice at every step / keep validation in your own hands; bottom callback "Back to those three answers at the start" | ListStack | Three rows land top to bottom, row 3 highlighted, top big text scales in after a delay | Three rows → row 3 → top big text | 1.5s |
