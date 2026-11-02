# cover.py · Atuntun-style Xiaohongshu cover image renderer

Renders a "copy plan (prompt)" straight into a finished cover image: HTML/CSS laid out per the Atuntun spec at
1080×1440 (3:4) → Playwright headless Chrome screenshot to PNG. All large text goes through CSS,
never text-to-image, eliminating wrong characters. The person image only gets a circular crop + stroke; faces are never generated or redrawn.

## Usage

```
python tools\cover\cover.py --title "<main-title>" --person <absolute-path-to-person-image> --out <absolute-output-png-path> [optional args]
```

## Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--title` | Yes | — | Main title, large characters on top (extra-bold sans + light-yellow fill + thick black stroke) |
| `--person` | One of two | — | Absolute path to the person asset (a real photo / avatar, a genuine bitmap); mutually exclusive with `--no-person` |
| `--no-person` | One of two | — | No-person variant (when there is no suitable real photo); the layout auto-centers vertically with no gaps |
| `--out` | Yes | — | Absolute output PNG path, strictly 1080×1440 |
| `--subtitle` | No | empty | Subtitle (style 1: white bold; style 4: light-yellow banner at the bottom) |
| `--style` | No | 1 | Style: 1 = large characters on top, 4 = tutorial checklist; other numbers error out |
| `--accent` | No | `#FDFFA7` | Primary color (soft light yellow), used for title fill/stroke/banner |
| `--bg` | No | `#0d1117` | Background color (GitHub dark); gradient and vignette are derived automatically |
| `--items` | No | — | Green ✅ checklist items for style 4; pass repeatedly |
| `--caption` | No | empty | Source attribution text at the bottom |
| `--stickers` | No | on | Theme sticker switch for style 1 (emoji decoration, theme-neutral); `--no-stickers` turns it off |
| `--sticker-label` | No | empty | Main copy for the style-1 text-card sticker; **not passing it means no card**; reusing the previous episode's copy is forbidden |
| `--sticker-sub` | No | empty | Secondary copy for the text-card sticker, used with `--sticker-label` |

## Examples

```powershell
# Style 1: large characters on top
python tools\cover\cover.py --title "The toolkit an expert finally open-sourced" --subtitle "AI writes code without crashing" `
  --person "<absolute-path-to-avatar-image>" --style 1 `
  --caption "Cover person: name withheld, public GitHub avatar · used as material only" --out $env:TEMP\c1.png

# Style 4: tutorial checklist (person on the right + green checklist on the left + bottom banner)
python tools\cover\cover.py --title "Install Skills with one command" --subtitle "Free, open source, composable" `
  --person "<absolute-path-to-avatar-image>" --style 4 `
  --items "One command to install, self-updating, never expires" --items "Includes tdd / grill-me skills" --items "Free and open source" `
  --out $env:TEMP\c4.png
```

## Dependencies

- Local Chrome (Playwright channel "chrome", headless)
- `tools/record/node_modules/playwright-core` (run `npm install` under `tools/record`)
- node.exe on PATH, or specify an absolute path with the `NODE_EXE` environment variable

The intermediate HTML file is written to the system temp directory and deleted after the screenshot, so no junk is left in the project directory.
