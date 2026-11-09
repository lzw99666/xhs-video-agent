# Contributing

**English** | [中文版](CONTRIBUTING.zh-CN.md)

Thanks for taking the time to improve xhs-video-agent. This repository is a **documented pipeline** first and code second — a change usually means updating a doc, a gate, and an example together.

## Ways to contribute

- **Bug report**: a step in `docs/WORKFLOW.md` does not behave as described, a gate misfires, a script breaks on a clean machine.
- **Feature request**: a new beat type, gate check, TTS provider, publishing adapter.
- **Docs / translation**: the English and `*.zh-CN.md` versions drift apart; a paragraph is outdated or unclear.
- **Example**: a new complete episode under `examples/` (text assets only, no video files).

## Before you start

1. Read [`README.md`](README.md) (or [`README.zh-CN.md`](README.zh-CN.md)) and [`docs/WORKFLOW.md`](docs/WORKFLOW.md). Most "bugs" are missing prerequisites.
2. Search existing issues and pull requests so we do not duplicate work.
3. For anything larger than a bug fix, open an issue first and describe **what problem you hit** and **which step of the flow it blocks**. Small PRs are much easier to review than large refactors.

## Fork and PR workflow

```bash
# 1. Fork on GitHub, then clone your fork
git clone https://github.com/<your-name>/xhs-video-agent.git
cd xhs-video-agent

# 2. Keep a remote for upstream
git remote add upstream https://github.com/lzw99666/xhs-video-agent.git

# 3. Branch from the latest main (never push directly to main)
git fetch upstream
git checkout -b fix/gate-audio-check upstream/main

# 4. Make the change, then commit with a scoped message
git add -A
git commit -m "fix(gate): audio check now skips beats with no narration"

# 5. Push to your fork and open the PR against main
git push -u origin fix/gate-audio-check
gh pr create --base main --title "fix(gate): audio check now skips beats with no narration"
```

There is also a long-lived integration branch, **`feature`**, used for larger work that needs several commits before it is ready for `main`. Branch from it when your change spans multiple steps (for example a new TTS provider); PR it back into `feature`, and `feature` is merged into `main` once the whole feature is verified.

## What a good PR contains

- **One concern per PR.** Do not mix a gate fix with a README rewrite.
- **A reason.** The PR body should say what breaks today, not only what you changed.
- **Verification output.** Paste the commands you ran and their exit codes (see below).
- **Docs in sync.** If you change a gate, update `docs/WORKFLOW.md` **and** `docs/WORKFLOW.zh-CN.md`. If you add a template field, update `templates/` in both languages.
- **No private data.** Never commit `account.md`, `log.md`, `.cheat-state.json`, `backlog.json`, predictions, cookies, `session.json`, metrics data, or any `*.mp4`.

## Local verification

Run these before opening the PR; CI is not configured, so the reviewer relies on your output.

```powershell
# PowerShell syntax + BOM discipline
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\normalize-bom.ps1 -Check
Get-ChildItem tools -Recurse -Filter *.ps1 | ForEach-Object {
  $e = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$e) | Out-Null
  if ($e) { "$($_.Name): $($e[0].Message)" }
}

# Python / Node syntax
python -X utf8 -m py_compile tools\record\build_master.py tools\record\verify_sync.py `
  tools\pipeline\compress-audit.py tools\pipeline\blind-read-check.py `
  tools\research\fetch_sources.py tools\cover\cover.py
node --check tools\record\record.mjs
node --check tools\record\shot.mjs
node --check tools\metrics\login.js
node --check tools\metrics\pull.js

# The example must still pass the gate
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 `
  -ProjectDir examples\ep11-sampling -Gate pre-code
# expected: pass=19 warn=1 fail=0, EXIT=0
# the single WARN is C14: the English sample script estimates 185s, 5s over the 180s cap

# Documentation must stay bilingual
# (every English doc has a sibling *.zh-CN.md and a language switcher line)
```

If your change touches a gate, also run the other gates you can run locally:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 -ProjectDir examples\ep11-sampling -Gate pre-script
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 -ProjectDir examples\ep11-sampling -Gate delivery
```

(`delivery` is expected to fail on the sample because it has no rendered video or audio — that is a real missing artifact, not a regression.)

## Style

- **Commits**: `type(scope): summary`, e.g. `fix(gate): ...`, `docs(workflow): ...`, `feat(tts): ...`. Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.
- **Code comments**: English only, in every script.
- **Docs**: English in the main file, Chinese in the `.zh-CN.md` sibling. Do not leave one side stale.
- **Paths**: relative to the repository root, or configurable through environment variables (see README section 8). No hard-coded absolute paths, usernames, or machine-specific settings.
- **Dependencies**: do not vendor third-party skills; point to upstream instead and update the dependency table in the README.

## Review process

- A maintainer reviews within a few days; ping the PR if it goes quiet for a week.
- Expect questions about the failing case you are fixing — reproducible steps help more than a long explanation.
- Docs-only PRs are usually merged quickly; gate changes need the example project to keep passing.

## License

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE).
