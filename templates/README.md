# templates — where to copy them

These files are **skeletons**, not ready-to-publish output. Replace the content after copying.

| Template | Copy to | Notes |
|---|---|---|
| `account.md` | `<repo-root>/account.md` | Account settings (persona / audience / content lines / red lines). Read before every episode. |
| `log.md` | `<repo-root>/log.md` | Single source of truth for publishing records; `validate.ps1`'s "posts today" reads it here. |
| `episode/` | `<repo-root>/videos/<episode-name>/` | The five-file set for one video: research card / design intent / narration script / shot outline / copy self-check. |

## Which runtime files you also need

- `.cheat-state.json`: created by `cheat-on-content`'s `/cheat-init` (includes the prediction hash lock).
- `backlog.json`: create it only when you want to run the unattended heartbeat; a single video does not need it.
- `predictions/`, `scripts/`, `candidates.md`: also created by `/cheat-init`.

## Copy commands

```powershell
# Account and log (do this once)
Copy-Item templates\account.md account.md
Copy-Item templates\log.md log.md

# A new episode
New-Item -ItemType Directory -Force videos\my-ep01
Copy-Item templates\episode\* videos\my-ep01\
```

> At the skeleton stage `check.ps1` will warn (the files are not filled in yet); that is expected. Run the gates once the content is final.
