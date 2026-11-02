<#
shots-review.ps1 —— frame-extraction review scaffold (added 2026-10-18)

Purpose: cover the blind spot of the text-level gate (check.ps1) — "cannot read the visuals". Following the master timeline (marks.json), extract
      one frame per beat and generate a [manual review checklist] for verifying the semantic issues a machine cannot catch:
      (1) do chart values match their labels  (2) is each beat informative enough  (3) are example sources attributed
      (4) is the hook resolved at the end, do chapters connect  (5) whitespace and pacing.
      (Born from the ep06 retro: bar chart only rendered the first bar, four pure-text cards in the second half, captions without sources — all slipped past check.ps1)

Usage (run from the repo root):
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/pipeline/shots-review.ps1 `
      -ProjectDir videos/regular-ep09-reliability

Output (writes to a temp area by default, does not pollute the project dir):
  frame images + shots-review.md → %TEMP%\shots-review\<ep>\      (override with -OutDir)

Exit codes: 0 = generated successfully; 2 = argument/environment error (video / marks.json / usable ffmpeg not found)
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ProjectDir,
  [string]$Video,
  [string]$OutDir,
  [int]$Width = 720
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

try { $root = (Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop).Path }
catch { Write-Output "ERROR: ProjectDir does not exist: $ProjectDir"; exit 2 }
$ep   = Split-Path $root -Leaf
$pres = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'presentation' } | Select-Object -First 1

# --- video ---
if ($Video) {
  try { $video = (Resolve-Path -LiteralPath $Video -ErrorAction Stop).Path } catch { Write-Output "ERROR: video does not exist: $Video"; exit 2 }
}
else {
  $cand = @(Get-ChildItem -LiteralPath $root -Filter '*.mp4' -ErrorAction SilentlyContinue)
  if ($pres) { $cand += @(Get-ChildItem -LiteralPath $pres.FullName -Filter '*.mp4' -ErrorAction SilentlyContinue) }
  if (-not $cand) { Write-Output "ERROR: no mp4 found (specify one with -Video)"; exit 2 }
  $video = ($cand | Sort-Object Length -Descending | Select-Object -First 1).FullName
}

# --- marks.json (master timeline) ---
$marks = $null
$mc = @()
if ($pres) {
  $mc += (Join-Path $pres.FullName 'raw\marks.json')
  $mc += (Join-Path $pres.FullName 'raw-vertical\marks.json')
}
$mc += (Join-Path $root 'raw\marks.json')
$mc += (Join-Path $root 'raw-vertical\marks.json')
foreach ($p in $mc) { if ((-not $marks) -and (Test-Path -LiteralPath $p)) { $marks = $p } }
if (-not $marks) { Write-Output "ERROR: marks.json (master timeline) not found"; exit 2 }

# --- beats.json (narration text) ---
$beatText = @{}
$beats = Join-Path $root 'beats.json'
if (Test-Path -LiteralPath $beats) {
  foreach ($b in @((Get-Content -LiteralPath $beats -Raw -Encoding UTF8 | ConvertFrom-Json))) { $beatText[$b.step_id] = $b.text }
}

# --- ffmpeg resolution (the Windows PATH build may be a broken shim → fall back to WSL) ---
$useWsl = $false
$saved = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
try { & ffmpeg -version *>$null; if ($LASTEXITCODE -ne 0) { $useWsl = $true } }
catch { $useWsl = $true }
if ($useWsl) {
  try { & wsl -e bash -lc 'which ffmpeg' *>$null; if ($LASTEXITCODE -ne 0) { throw } }
  catch { $ErrorActionPreference = $saved; Write-Output "ERROR: no usable ffmpeg (neither Windows nor WSL)"; exit 2 }
  Write-Output "[INFO] Windows ffmpeg unavailable, switching to WSL ffmpeg"
}
$ErrorActionPreference = $saved

function To-Wsl([string]$p) {
  if ($p -match '^([A-Za-z]):[\\/](.*)$') { return ('/mnt/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/')) }
  return ($p -replace '\\', '/')
}

$out = if ($OutDir) { $OutDir } else { Join-Path $env:TEMP ("shots-review\" + $ep) }
New-Item -ItemType Directory -Force -Path $out | Out-Null

$mj  = Get-Content -LiteralPath $marks -Raw -Encoding UTF8 | ConvertFrom-Json
$ids = @($mj.marks | ForEach-Object { $_.id })
$ts  = @($mj.marks | ForEach-Object { [double]$_.t })

# Video duration (used for the last beat)
$durMs = $ts[-1] + 5000
try {
  if ($useWsl) { $d = & wsl -e bash -lc ("ffprobe -v error -show_entries format=duration -of csv=p=0 '" + (To-Wsl $video) + "'") 2>$null }
  else         { $d = & ffprobe -v error -show_entries format=duration -of csv=p=0 $video 2>$null }
  if ($d) { $durMs = [double]($d | Select-Object -First 1) * 1000 }
} catch { }

$rows = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $ids.Count; $i++) {
  $t    = $ts[$i]
  $next = if ($i + 1 -lt $ts.Count) { $ts[$i + 1] } else { $durMs }
  if (($next - $t) -lt 900) { $mid = $t + (($next - $t) * 0.8) } else { $mid = $t + (($next - $t) * 0.5) }
  $sec = [math]::Round($mid / 1000.0, 2)
  $id  = $ids[$i]
  $img = Join-Path $out ($id.Replace(':', '_') + '.png')
  if ($useWsl) {
    & wsl -e bash -lc ("ffmpeg -loglevel error -ss $sec -i '" + (To-Wsl $video) + "' -frames:v 1 -vf scale=${Width}:-1 '" + (To-Wsl $img) + "' -y") 2>$null
  }
  else {
    & ffmpeg -loglevel error -ss $sec -i $video -frames:v 1 -vf "scale=${Width}:-1" $img -y 2>$null
  }
  [void]$rows.Add([pscustomobject]@{ Id = $id; Sec = $sec; Img = $img; Text = $beatText[$id] })
  Write-Output ("[{0}/{1}] {2} @ {3}s -> {4}" -f ($i + 1), $ids.Count, $id, $sec, (Split-Path $img -Leaf))
}

$md = Join-Path $out 'shots-review.md'
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Frame review checklist · $ep")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("> Generated by tools\pipeline\shots-review.ps1 (do not edit the structure by hand). Check each beat, then tick the boxes.")
[void]$sb.AppendLine("> Covers the semantic issues a machine cannot catch: chart values vs labels / information per beat / example sources cited / hook payoff and transitions / whitespace pacing.")
[void]$sb.AppendLine("> Video: ``$video``")
[void]$sb.AppendLine("> Frame dir: ``$out``")
[void]$sb.AppendLine("")
foreach ($r in $rows) {
  [void]$sb.AppendLine("### $($r.Id) · $($r.Sec)s")
  if ($r.Text) { [void]$sb.AppendLine("- Narration: $($r.Text)") }
  [void]$sb.AppendLine("- Frame: ``$($r.Img)``")
  [void]$sb.AppendLine("- [ ] chart values match labels　[ ] enough information　[ ] example sources cited　[ ] hook/transition works")
  [void]$sb.AppendLine("- Notes:")
  [void]$sb.AppendLine("")
}
$sb.ToString() | Set-Content -LiteralPath $md -Encoding UTF8

Write-Output ""
Write-Output "OK: checklist -> $md"
Write-Output ("    frames = {0} (dir: {1})" -f $rows.Count, $out)
exit 0
