# Operations log (single source of truth for publishing records)

> Append one entry immediately after every publish. `validate.ps1`'s "posts today / 2h gap" follows this file.
> The entry format is fixed for mechanical reading: `## YYYY-MM-DD · post N · <episode>`

---

## YYYY-MM-DD · post 1 · <episode>

- **Title**: <≤20 characters>
- **Format**: video / image-text
- **Duration**: <seconds>
- **Prediction file**: `predictions/<date>_<id>_<short>.md`
- **URL**: <paste after publishing>
- **Published at**: <YYYY-MM-DD HH:MM>
- **First frame**: <one-sentence description>
- **Notes**: <anomalies / version / who confirmed>

---

## Weekly retro (YYYY-MM-DD)

- Published this week: <N> posts
- Average watch seconds per viewer: <median / best / worst>
- Predictions that hit: <which ones>
- Actions for next week: <max 3, executable>
