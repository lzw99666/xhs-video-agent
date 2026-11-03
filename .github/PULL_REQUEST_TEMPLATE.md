## What breaks today

<!-- The failing step, the command, and what you expected instead. Link the issue if there is one. -->

## What this PR changes

<!-- One concern per PR. List the files that matter, not every touched file. -->

## How I verified it

```powershell
# paste commands and exit codes here
```

- [ ] `tools\pipeline\check.ps1 -ProjectDir examples\ep11-sampling -Gate pre-code` → pass=19 fail=0
- [ ] `.ps1` BOM check passes (`normalize-bom.ps1 -Check`)
- [ ] Python / Node syntax checks pass
- [ ] Docs updated on both sides (English + `*.zh-CN.md`)

## Checklist

- [ ] No private data committed (`account.md`, `log.md`, `.cheat-state.json`, cookies, `session.json`, metrics, `*.mp4`)
- [ ] No hard-coded absolute paths or usernames
- [ ] Commit messages follow `type(scope): summary`
- [ ] I read `CONTRIBUTING.md`

## Notes for the reviewer

<!-- Anything you are unsure about, or follow-up work that is out of scope. -->
