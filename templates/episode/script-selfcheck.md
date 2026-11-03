# script-selfcheck · <episode> (<beat-count> beats / <character-count> characters / estimated <seconds>s)

**English** | [中文版](script-selfcheck.zh-CN.md)

> Walk through the four-layer self-check in `web-video-presentation/references/SCRIPT-STYLE.md` item by item → revise per failing item → then finalize.
> How it is executed: an isolated sub-agent blind-reads and restates (layer four) + the lead strictly checks each item (layers one to three).
> Final character count: `script.md` <N> (including punctuation) / <M> characters / <beat-count> beats; `article.md` <A> → information retention **<X>%** (≥60% passes).

## 1. Form layer (8 principles)

| # | Principle | Verdict | Evidence / action |
|---|---|---|---|
| 0 | Information retention ≥60% | <PASS/FAIL> | <the arithmetic + each key fact present in the script> |
| 1 | Colloquial | <...> | <...> |
| 4 | Opening has a hook | <...> | <the first sentence, verbatim> |
| 5 | `---` splits ideas | <...> | <beat count> |
| 8 | Concrete examples first | <...> | <three concrete objects> |

## 2. Substance layer (five anti-AI-feel categories)

| Category | Verdict | Action |
|---|---|---|
| Fake empathy / fake depth / self-promotion / universal template / piled-up parallelism | <...> | <which line was cut, and why> |
| Closing CTA | <...> | <the action, verbatim> |

## 3. Read-aloud test

<Read each paragraph aloud, list the sentences you cannot say out loud → how to fix. Write "none" if there are none.>

## 4. Structure layer (classification tree / terminology / numbering / callback / compression / transitions / landing the topic)

| # | Check item | Verdict | Evidence |
|---|---|---|---|
| 1 | Classification tree is self-consistent | <...> | <...> |
| 2 | Terminology ledger / explained at first occurrence | <...> | <each term's beat, action before name> |
| 3 | Numbered items are listed | <...> | <...> |
| 4 | Callback is set up in advance | <...> | <planted in which beat, collected in which beat> |
| 6 | Transitions between chapters | <...> | <the reason each chapter follows> |
| 7 | Opening lands the topic | <...> | <subject / what / why worth watching, which beat completes each> |

### Blind-read restatement (isolated sub-agent, reads only `script.md`)

- Classification tree: <restatement>
- Terminology list: <restatement>
- Chapter-by-chapter logic chain: <restatement>
- Where the topic lands: <which beat>
- Subject named: <which beat it appears in>

## 5. cheat view (v1-retention five-dimension self-score)

> Scoring discipline: do not look at `data/metrics`; give one integer per dimension backed by evidence inside the script.

| Dimension | Score | Original line from the script as evidence |
|---|---|---|
| **HO** Hook & Hold | <0–5> | <original line> |
| **PE** Payoff Density | <0–5> | <original line> |
| **TK** Transferability | <0–5> | <original line> |
| **NA** One Line | <0–5> | <original line> |
| **QL** Quotable | <0–5> | <original line> |

**Self-scored composite** = (HO×2 + PE×2 + TK×1.5 + NA×1 + QL×0.5) ÷ 7 × 2 = **<score>**

The blind prediction is written separately by `cheat-predict`'s isolated sub-agent; when they differ by ≥2 points, note it in the prediction file.
