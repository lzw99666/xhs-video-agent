# Account settings (single source of truth)

**English** | [中文版](account.zh-CN.md)

> Read this before every episode; this file and `log.md` are the process's "external memory".
> Think before changing the persona / red lines: downstream titles, scripts and publishing checks all follow this.

## 1. Persona

- **Identity**: <who you are / what you are learning / what verifiable experience you have>
- **Tone**: <e.g. sincere learner, plain language, no posturing>
- **What you do not fake**: <areas you explicitly do not pretend to understand>
- **Catchphrases / banned words**: <list what you never say>

## 2. Audience

- **Core group**: <age / occupation / what problem they are solving>
- **Their default state**: <what they already know, what they do not know yet>
- **Why they would follow you**: <one sentence>

## 3. Content lines

| Line | Format | Spec | Goal |
|---|---|---|---|
| Regular line | Mechanism explainer / tool test | 3:4 vertical 1080×1440, 120–180s | Retention |
| Experimental line | Single-variable comparison | Same as above | Validate one hypothesis |
| Image-text line | Checklist / tutorial | 3:4 image-text | Saves |

## 4. Title red lines

- Title ≤ 20 characters (`validate.ps1` hard check).
- No empty promises like "shocking / must-see / 99% of people don't know".
- The title must be carried by the first frame's image; this account sets no separate cover image, **the first frame is the cover image**.

## 5. Publishing red lines

- ≤ 2 posts per day, ≥ 2h apart (`validate.ps1` reads `log.md` and `.cheat-state.json`).
- Do not publish without a verified prediction file (the blind prediction hash lock must match).
- Publishing requires human confirmation; `publish: "auto"` is only discussed after 5 consecutive episodes with zero anomalies.
- Do not delete comments, do not fake engagement, do not touch platform risk controls.

## 6. Visuals

- Vertical 3:4: 1080×1440.
- Primary color / background / fonts: <fill in, then align with the theme tokens in `outline.md`>.
- The first frame carries the title's job: large title + hook + one concrete object.

## 7. History

| Date | Event | Conclusion |
|---|---|---|
| YYYY-MM-DD | <publish / revamp / retro> | <one sentence> |
