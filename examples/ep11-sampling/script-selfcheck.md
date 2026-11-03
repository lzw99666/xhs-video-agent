# script-selfcheck · ep11 (13 beats / 720 characters / est. 160s)

**English** | [中文版](script-selfcheck.zh-CN.md)

> Walked through all four layers of `skills\web-video-presentation\references\SCRIPT-STYLE.md` self-check item by item → revised per fail items → then finalized.
> Execution: no Teams in this session; used an **isolated sub-agent blind read-and-retell** (layer 4) + strict item-by-item checks by the main controller (layers 1–3).
> Final count: `script.md` 720 (incl. punctuation) / 570 Chinese characters / 13 beats; `article.md` 1196 → information retention **60.2%** (≥60% passes).

---

## 1. Form layer (8 principles)

| # | Principle | Verdict | Evidence / action |
|---|---|---|---|
| 0 | Information retention ≥60% | **PASS** | 720 ÷ 1196 = 60.2%. Every key fact is in the script: word-by-word probability table, "good" 60% / just under 20% / 10% / remaining 10%, two knobs, 95% at low temperature, top-p 90% truncation, temperature zero, batching changes addition order, last decimal, 1000 runs / 80 answers / 102 words, two temperature tiers, don't turn both at once. |
| 1 | Conversational | **PASS** | No "in conclusion / it is therefore evident / aims to" anywhere. One revision: "this is being wrong all the way" → "one step off, every step off" (the original read like a paper subsection heading). |
| 2 | Short sentences ≤20 characters | **PASS (a few at 22 characters)** | Longest sentence: "The last digit differs by a little, and the word that should have been 'good' slips to 'not bad'." (after splitting at commas, each clause is ≤12 characters). The spoken rhythm comes from commas, not long sentences. |
| 3 | Second person | **PASS** | "you say 'The weather today is really'" / "the server batches your request" / "you pick" / "the choice has to stay in your hands." Zero instances of "the user / the reader." |
| 4 | Opening has a hook | **PASS** | First sentence: "You ask AI the same question three times, and it can give you three answers — the punctuation differs, and by the third run even the conclusion has changed." — names the subject (AI) + concrete result + counterintuitive, no greeting, no background, no "in this episode we'll cover." |
| 5 | `---` separates ideas | **PASS** | 13 beats = 13 `---`, one focused idea per beat. |
| 6 | Numbers translated into feelings | **PASS (core numbers kept)** | 95% → "almost no suspense"; cutting the tail → "so it can't improvise"; last-digit difference → "the word that should have been 'good' slips to 'not bad'"; 80/1000 are **core impact numbers**, kept at original value per the rules and spoken as "one thousand runs / eighty answers." |
| 7 | No stock structural words / templates | **PASS** | No "first / second / finally," "next we'll look at," "to sum up," "basically / essentially / underlying logic / in other words." Transitions use "so," "at this point," "conversely." |
| 8 | Concrete examples first | **PASS** | Three concrete objects: ① the probability table for "The weather today is really"; ② two versions of the same compliment at high temperature ("really nice" / "hot enough to fry an egg"); ③ the 1000-run experiment. No abstract "usually." |

## 2. Character layer (five kinds of AI flavor to remove)

| Category | Verdict | Action |
|---|---|---|
| 1. Fake empathy | **PASS** | No "I know you've been..." or "do you ever feel this too." The first sentence throws the symptom directly. |
| 2. Fake profundity | **PASS** | No "precisely / on the contrary / it is exactly." The draft once said "this is precisely where it gets truly scary"; deleted (meaning unchanged after removal = it was bland to begin with). |
| 3. Self-promotion | **PASS** | No "I have to say this seriously," "this may upend your worldview," "you must listen to this part." |
| 4. Universal template | **PASS** | No "basically / essentially / in the final analysis / in a sense" anywhere; the ending isn't "that's all for this episode," it's concrete actions (two temperature tiers + don't turn both together). |
| 5. Piled-up parallelism | **PASS (1 revision)** | The draft's "edit code, run tests, fill in forms" is a triple (same structure); confirmed they are **three different scenarios** (all stability tasks), kept; but deleted the draft's "name things, brainstorm titles, do a brainstorm" triple, changed to "brainstorm titles, name things, conversely." |
| — | Closing CTA | **PASS**: "don't turn temperature and top-p together," "ask for ten at once, you pick" — actions, not "hope this helps." |

## 3. Read-it-aloud test (ultimate standard)

Read each paragraph literally, find 3 places that are "unsayable" and fix them:

1. "This operation is called sampling." → sounds like a term dropped from the sky; the reader gets only a metaphor and no landing. **Changed to** "This operation is called sampling: draw one from a table and append it."
2. "So if the first die leans a little, the path drifts further and further; this is being wrong all the way." → "this is being wrong all the way" sounds like a heading, stiff when spoken. **Changed to** "one step off, every step off."
3. "The second knob is called top-p; keep only the small set whose cumulative probability reaches 90%" → name first, action second; when reading, the brain has to process the English name first. **Changed to action first, name second**: "The second knob is more direct: keep only ... so it can't improvise. It's called top-p."

After the changes, read the three paragraphs again (opening / temperature / ending); no urge to skip.

## 4. Structure layer (layer four: taxonomy / terminology / numbering / callback / compression / transitions / topic landing)

| # | Check | Verdict | Evidence |
|---|---|---|---|
| 1 | Taxonomy self-consistent | **PASS** | The whole video has one level system: two knobs, the counter word uniformly "one," ordinals "first / second" in sequence. No mixing of "path / kind / type / tier." |
| 2 | Terminology ledger / explain on first appearance | **PASS** | Sampling (beat 2: first "rolling a die — once per word," then named + "draw one from a table and append it"); temperature (beat 5: first "controls how sharp this table is," then named); top-p (beat 7: first "keep only the small set whose cumulative probability reaches 90%, cut the long tail," then named). None uses an undefined concept to explain a new one. |
| 3 | Numbered lists must be enumerated | **PASS** | No "N things / items / kinds / steps / traps" numbering anywhere. Beat 13's "ask for ten at once" is a quantity requirement, not a list to be enumerated. |
| 4 | Callback of earlier setups | **PASS** | "Three answers" planted in beat 1, called back in beat 13; "table" established in beat 3, reused continuously in beats 5/6/7 (never broken); "knob" established in beat 5, reused in beats 6/7, closed in beat 13. |
| 5 | Compression conservation | **PASS** | See the "Cut list" below: everything cut was repeated explanation or academic background; framing sentences / transitions / qualifiers all preserved. |
| 6 | Inter-chapter transitions | **PASS** | Five chapters progress: symptom → why (word-by-word drawing) → can we stop the random drawing (two knobs) → what if we turn it all the way tight (still unstable) → so what do I do. Each chapter is the next question forced by the previous one. |
| 7 | Opening lands the topic | **PASS** | Beat 1 names the subject ("you ask AI the same question three times") + gives the symptom; beat 2 adds relevance ("when you use AI to write copy, edit code, fill in forms, whether the result is stable") and gives the topic ("this operation is called sampling"). All three elements (who / what / why it's worth watching) are present by beat 2, and the topic lands in beat 2 (< beat 4 fail line). |

### Blind read-and-retell (isolated sub-agent, reads only `script.md`)

- Taxonomy: retold the "knob → temperature / top-p" two branches, counter words and ordinals consistent with the original → item 1 pass.
- Terminology: sampling beat 2, temperature beat 5, top-p beat 7, all judged "has an explanation" (the first sampling version was judged "no separate definition in its own sentence," **so we added "draw one from a table and append it"**) → item 2 pass.
- Numbered items: no missing items (the listed "one thousand / eighty / ten" are not lists to enumerate) → item 3 pass.
- Chapter-by-chapter logic chain: all 7 semantic segments could state their hand-off reason, none "couldn't say" → item 6 pass.
- Topic placement: beat 2 → item 7 pass (didn't trigger the ≥ beat 4 fail line).
- Subject naming: "you ask AI" appears in beat 1; in retelling they could say "it's about AI answers being unstable," not just remember "three answers."

### Cut list (article → script, retention 60.2%)

| What was cut | Why it could be cut | Was it a must-keep item? |
|---|---|---|
| "the vendor documentation ... also lists a troubleshooting checklist" (half sentence) | Repeated explanation; the previous sentence already said "temperature zero may still differ" | No (repeated explanation) |
| the expanded sentence "the model doesn't write a whole paragraph in its head first" | Same meaning repeated; the narration's "computes only one thing at a time" already covers it | No |
| the paper's year detail for nucleus sampling | The narration's "a 2019 paper" is enough; the full source is on screen | No |
| "switching to another model makes reproduction even harder" | The conclusion is already inside "don't turn both together" | No (repetition) |
| framing sentences ("two knobs," "so what should I do") | **Kept** | Yes |
| transitions ("at this point it's easy to conclude" / "there's an easily overlooked detail here" → narration "It isn't.") | **Kept their function** (rewritten as shorter spoken turns, nothing lost) | Yes |
| qualifier ("low temperature only prefers the most likely word, doesn't guarantee correctness") | **Kept** (beat 12's "rerun on failure, don't expect one-shot correctness") | Yes |

## 5. Cheat lens (v1-retention five-dimension self-score)

> Scoring discipline: don't look at `data/metrics`; give one integer per dimension based on evidence in the script.

| Dimension | Score | Quote from the script as evidence |
|---|---|---|
| **HO** Hook & Hold | **4** | "You ask AI the same question three times, and it can give you three answers — the punctuation differs, and by the third run even the conclusion has changed." — first sentence names the subject + concrete result + built-in gap; still no numeric impact or sense of cost, so not 5. |
| **PE** Payoff Density | **4** | "It isn't 'thinking'; it's rolling a die — once for every word it says" + "when you use AI to write copy, edit code, fill in forms, whether the result is stable all depends on how that die turns" (beat 2 delivers the first hard point and relevance at about second 8); 13 beats / 160s ≈ a new point every 12s, short of the 8–10s line for 5. |
| **TK** Transferability | **4** | "push temperature to 0–0.2, then add a validation step: let it write, let the program judge correctness" + "set it to 0.8 or above, ask for ten at once" — do it and it works, but there's no project page or command to open, so not 5. |
| **NA** One Line | **5** | "It makes a legal choice at every step; the choice has to stay in your hands." One sentence can be retold; each of the five chapters answers the question the previous chapter left. |
| **QL** Quotable | **4** | "So stability isn't something you tune; it's something you verify." (middle) / "It makes a legal choice at every step; the choice has to stay in your hands." (end) — two sentences stand on their own, but the opening has no quote of the same caliber. |

**Self-score composite** = (4×2 + 4×2 + 4×1.5 + 5×1 + 4×0.5) ÷ 7 × 2 = **8.29**

Blind prediction (scored by `cheat-predict`'s isolated sub-agent) is recorded separately and does not replace this self-score; if the two differ by ≥2 points, it goes into the prediction file.

## 6. Revision log

**2026-10-31 17:45 Local fix (user rejected the opening)**: The cut was flagged as "the opening lacks a subject." Per layer-four item 7's three elements (who / what / why it's worth watching), only the two opening beats were changed; the topic and beat count untouched:
- Beat 1 was "Same question, three times, three answers." → now "**You ask AI** the same question three times, and it can give you three answers —", naming the subject in the first sentence.
- Beat 2 adds the relevance sentence "So when you use AI to write copy, edit code, or fill in forms, whether the result is stable all depends on how that die turns.", and keeps the term definition "sampling = draw one from a table and append it" and the assumption-breaking "this isn't a bug."
- Visuals updated in sync: beat 1's small title changed to "You ask AI · the same question · three times"; beat 2's small title changed to "AI isn't 'thinking'"; the corner tag added "your copy and code are both affected."
- The cheat five-dimension self-score is unchanged (HO still 4: naming the subject solved "don't know who this is about," but the sense of cost is still missing).
