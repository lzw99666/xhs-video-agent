# facts · reg-ep11-2min

**English** | [中文版](facts.zh-CN.md)

**Topic**: Why does AI answer the same question differently every time?
**Research date**: 2026-10-31
**One-line conclusion**: Every word a model emits is one draw from a probability table, and two knobs (temperature / top-p) determine how wild that table is. But turning the knobs to their tightest (temperature 0) **still** doesn't guarantee identical output — the reason isn't the random number generator, it's that servers batch different requests together and the order of floating-point additions changes.

---

## 1. Source list (multi-source cross-check)

| ID | Source | Type | Supports | Checked |
|---|---|---|---|---|
| S1 | OpenAI Help Center, "Why am I getting different completions on Playground vs the API" | Vendor official help doc (public web) | "temperature > 0 means random output; different results are expected"; "use temperature 0 for consistency"; "the troubleshooting checklist when temperature 0 still differs" | Original text checked 2026-10-31 |
| S2 | Holtzman et al., "The Curious Case of Neural Text Degeneration," arXiv:1904.09751 (ICLR 2020) | Peer-reviewed paper (public web) | Definition and motivation of nucleus sampling (top-p): cut off the unreliable long tail while preserving fluency and diversity | Abstract checked 2026-10-31 |
| S3 | Thinking Machines, "Defeating Nondeterminism in LLM Inference" (2025-09) | Technical report from a frontier lab (public web) | The real reason temperature 0 is still nondeterministic: kernels are not batch-invariant + batch size varies with load; 1000 greedy decodes produced 80 unique results, diverging at token 103 | Full text checked 2026-10-31 |
| S4 | inferbase, "LLM Sampling Parameters Explained" / technologyonthe.net, "Sampling Settings and Reproducibility…" (2026-10) | Secondary technical write-ups (public web; two independent pieces pointing the same way) | Mechanism chain: logit → softmax → divide logits by temperature → top-p truncation; recommended temperature tiers by scenario; the common vendor advice "tune only one of temperature and top_p" | Checked 2026-10-31 |

Cross-relations: **mechanism chain (S2 + S4)** and **what temperature 0 is supposed to do (S1) versus why it falls short (S3)** each have at least two sources; "temperature 0 is still unstable" is supported by both S1 (admits differences remain at temperature 0) and S3 (gives the root cause and a quantified experiment). No single-source restatement.

> Scope boundaries (must hold when writing the script): temperature **ranges differ** across vendors (some 0–2, some 0–1), so the narration only uses relative phrasing such as "low / high / 0 / 0.8 and above," never a concrete range like "the maximum is 2." S3's 80/1000 is **their experiment on Qwen3-235B on their own inference stack**; the narration says "someone ran an experiment," not "all models behave this way."

---

## 2. Key data and sources

| ID | Data | Source | Narration usage |
|---|---|---|---|
| F1 | At each step the model scores every word in the vocabulary (logit), softmax turns the scores into probabilities, and the next word is drawn from this distribution | S3, S4 | Mechanism foundation, beats 3–4 |
| F2 | Temperature divides logits **before** softmax: <1 sharpens (top words dominate), >1 flattens (fringe words get a chance), approaching 0 is equivalent to greedy decoding (always take the highest score) | S4 (two pieces agree), S3 | Beats 5–6 |
| F3 | top-p (nucleus) keeps only the smallest word set whose cumulative probability reaches p, truncating the rest of the long tail | S2 (original paper), S4 | Beat 7 |
| F4 | Temperature >0 → random output, "different results are expected"; for consistent, repeatable output → temperature 0 | S1 (original text) | Beat 8's "this should be stable now" |
| F5 | Even at temperature 0, production inference services don't guarantee bit-level consistency: kernels are not invariant to **batch size** (the same row computed at different batch sizes can differ by as much as ~1669 in magnitude), and batch size varies with server load → reduction (addition) order changes → the last digits differ | S3 | Beat 9 |
| F6 | Same prompt, greedy decoding, **1000** runs → **80** unique results; the first **102** tokens are identical, divergence starts at token **103** | S3 (original experiment, Qwen3-235B) | Beat 10 (the narration says "word," meaning token) |
| F7 | Scenario tiers: extraction / classification / code / tool arguments → temperature 0 (or the lowest); retrieval-based Q&A → 0–0.3; writing / summarization → 0.5–0.8; brainstorming / multiple options → 0.8–1.0 with several candidates per request | S4 | Beats 12–13 |
| F8 | Common vendor advice: tune **only one** of temperature and top-p; adjusting both makes attribution and reproduction hard | S4 (secondary write-ups, marked as common advice) | One reminder in beat 13 |
| F9 | Low temperature only means "prefers the most likely word," **not** "guaranteed correct" — confidently wrong is still wrong | S4 | The premise of beat 12's "add a validation step" |

---

## 3. Abstract concepts → visual metaphors

| Abstract concept | Visual object (viz element) | Notes |
|---|---|---|
| Three different answers | Three chat bubbles (`ChatBubbles`) on one screen, each with different text | The first frame is the cover; the "same question" must be obvious at a glance |
| Probability table for the next word | Horizontal bars (`BarChart`), bar length = probability | Draw only the top four; represent the remaining 10% with one gray "other" bar |
| Word-by-word choices drifting apart | Forking path (connectors in `PipelineFlow` / two hand-drawn polylines) | The first fork is between "good / not bad" |
| Temperature sharpening / flattening the table | The same set of bars morphing between two sets of values + a temperature scale rail (low end labeled "sharp," high end labeled "flat") | Numbers change in sync: 95% → 30% |
| top-p cutting the tail | A knife line (a vertical dashed line) sweeps across; the long tail on the right grays out and collapses | "Keep only the cumulative 90%" |
| Server batching | Three "other people's requests" blocks crowd into a queue (`CardGrid` / hand-drawn queue) | More people in the batch → addition order changes |
| Last-decimal upset | Two candidate bars almost equal in height, differing by one decimal place; a pointer wobbles and slides to the other bar | Emphasize "just a tiny difference" |
| The 1000-run experiment | A dot matrix of 100 cells (`CardGrid` thumbnails), only a few repeats, most different | Big numbers 1000 / 80 / 103 pinned in the corner |
| Two knobs | Two knob icons + tier numbers (0–0.2 / 0.8 and above) | The takeaway object for the ending |

---

## 4. Teaching design

**Learning objectives**
After watching, someone who has never touched a parameter can: ① explain in one sentence "why the answer to the same question changes" (every word emitted is one draw from a probability table); ② name the two knobs and the direction each pushes; ③ pick a temperature tier for their own scenario (0–0.2 for stability, 0.8 and above for divergence) and know that **stability also requires validation**.

**Assumed audience background**
Has used ChatGPT / Claude / Doubao and has seen "ask again and the answer changes," but doesn't know what `temperature` / `top-p` are, doesn't know what a token is, and doesn't need to see formulas. No mathematical notation anywhere in the video; only two visual objects are kept: the "table" and the "bars."

**Full context for each example**

- **Example A: probability table for the next word** (beat 3). Question: on what basis can the model call "the next word"? Where do the candidates come from? — The candidates are the **entire vocabulary** (tens of thousands to hundreds of thousands of words); the model scores every word and softmax normalizes the scores into probabilities. The narration reads only the top four (good / not bad / hot / other), because the top four already account for 90%, and all remaining words combined are only 10%; the gray "other" bar on screen is that remaining 10%. Why this sentence "The weather today is really": it's everyday enough, unambiguous, and viewers can predict the answer themselves, so they can "see" the difference between the model and a human.
- **Example B: the same table at two temperatures** (beats 5–6). Question: what exactly does temperature change? Why are the candidates 0.2 and 1.5? — 0.2 represents "almost certain" (the top word is pushed to 95%), 1.5 represents "clearly divergent" (the top score drops to 30%, and fringe words still get 10%). These two values are not paper-recommended values; they are **extreme demonstrations of the same table in two directions**, meant to make the "sharp / flat" shape change visible; the specific percentages on screen are demonstration values, not measurements from any vendor.
- **Example C: the 1000-run greedy experiment** (beat 10). Question: is temperature 0 actually stable? Why 1000 runs? — S3 ran exactly 1000 greedy decodes of the same prompt and got 80 unique results; too few samples (say 5) wouldn't reveal the distribution, too many and viewers can't remember, so 1000 is the original scale, and the ratio "80/1000" is striking in itself. The divergence point at token 103 is also from the original; the narration says "divergence starts after the 102nd word."

**Experience translation**
- 95% → "almost no suspense" (not reading "95 percent," but making people feel "there's no choice")
- Cutting the tail → "so it can't improvise"
- Last-decimal upset → "the word that should have been 'good' slips to 'not bad'"
- 80 / 1000 → "what you thought was certainty is just one of a pile of outcomes"
- Temperature 0 is still unstable → "freeze the dice, and the table is still shaking"

**Ending (actionable advice + hook callback)**
Two tiers usable the same day (0–0.2 for stability + validation; 0.8 and above for divergence + ask for ten at a time) + one rule (don't turn temperature and top-p together) + callback to the first beat ("back to those three answers at the start") + one standalone landing line ("it makes a legal choice at every step; the choice has to stay in your hands").

**Argument chain · narrative arc**
One sentence locks the order of the whole video: **every word it says is a dice roll → the dice have two knobs → turn the knobs as tight as they go and it's still unstable → so stability comes from validation, not parameters.**

- Chapter 1 (beats 1–2) presents the symptom and the topic: three answers aren't a bug, they're "sampling." Hand-off: none (opening).
- Chapter 2 (beats 3–4) answers "why are they different": because it draws word by word from a probability table, and the first fork skews everything after it. Picks up Chapter 1's "why."
- Chapter 3 (beats 5–7) answers "can we stop it from drawing randomly": yes, two knobs; temperature controls how fat or thin the table is, top-p controls whether the tail stays. Picks up the "table" object left by Chapter 2.
- Chapter 4 (beats 8–10) answers "turning it all the way tight should be stable, right": it isn't, because batching changes the order of additions and the last decimal upsets the result; the 1000-run experiment gives the scale. Picks up Chapter 3's concrete "temperature 0" setting.
- Chapter 5 (beats 11–13) answers "so what should I do": per-scenario tiers + validation + one rule + callback to the opening. Picks up Chapter 4's "parameters can't save you."
