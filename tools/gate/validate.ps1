# validate.ps1 — mechanical pre-publish gate (WORKFLOW.md 9.2)
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate\validate.ps1 `
#   -Title "title" -TagsCount 6 -VideoPath "videos\x.mp4" -CoverPath "cover.png" `
#   -PredictionPath "predictions\x.md" [-NoteType video|image-text]
# Exit 0 only when every check passes; otherwise print [GATE-FAIL] <reason> and exit 1. The CLI must run this before publishing; non-zero blocks publishing.
# Checks: 1 title / 2 tags / 3 rendered video exists / 4 cover 1080x1440 (optional, skipped when not passed) / 5 prediction hash lock / 6 posts today / 7 2h gap / 8 halt
#         9 hard audio check (video notes only) — true loudness loudnorm I + true peak dBTP (not the volumedetect mean)
# NoteType=image-text (image-text notes) waives checks 3 and 9; everything else still runs.
param(
    [Parameter(Mandatory=$true)][string]$Title,
    [Parameter(Mandatory=$true)][int]$TagsCount,
    [string]$VideoPath = '',
    [string]$CoverPath = '',
    [Parameter(Mandatory=$true)][string]$PredictionPath,
    [ValidateSet('video','image-text')][string]$NoteType = 'video',
    [string]$RepoRoot = ''
)
$ErrorActionPreference = 'Stop'
$root = if ($RepoRoot) { (Resolve-Path -LiteralPath $RepoRoot).Path } else { (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$fails = @()

# 1. Title ≤20 characters
if ($Title.Length -gt 20) { $fails += "Title is $($Title.Length) characters, exceeding the 20-character limit" }

# 2. 3~6 tags
if ($TagsCount -lt 3 -or $TagsCount -gt 6) { $fails += "Tag count $TagsCount, must be 3~6" }

# 3. Rendered video exists (waived for image-text notes)
if ($NoteType -eq 'video') {
    if (-not $VideoPath) { $fails += 'Video notes must provide -VideoPath' }
    elseif (-not (Test-Path (Join-Path $root $VideoPath))) { $fails += "Rendered video not found: $VideoPath" }
}

# 4. Cover exists and is 1080x1440 (**optional**: on 2026-10-27 the user decided this account has no cover, the first frame is the cover)
if ($CoverPath) {
    $coverFull = Join-Path $root $CoverPath
    if (-not (Test-Path $coverFull)) {
        $fails += "Cover not found: $CoverPath"
    } else {
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile($coverFull)
        if ($img.Width -ne 1080 -or $img.Height -ne 1440) { $fails += "Cover size $($img.Width)x$($img.Height), must be 1080x1440" }
        $img.Dispose()
    }
} else {
    Write-Host '[GATE-WARN] No cover provided (this account has no cover, the first frame is the cover; make sure the first frame already carries the title role)'
}

# 5. Prediction file exists + hash lock matches
$predFull = Join-Path $root $PredictionPath
$statePath = Join-Path $root '.cheat-state.json'
$state = Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not (Test-Path $predFull)) {
    $fails += "Prediction file not found: $PredictionPath (a blind prediction is a hard pre-publish requirement)"
} else {
    $predKey = $PredictionPath -replace '\\', '/'
    $locked = $state.prediction_hashes.$predKey
    if (-not $locked) { $locked = $state.prediction_hashes.$PredictionPath }
    if (-not $locked) {
        $fails += "Prediction file has no registered hash lock (predict must write prediction_hashes when it saves the file)"
    } else {
        $lines = Get-Content $predFull -Encoding UTF8
        $startIdx = ($lines | Select-String -Pattern '^## Prediction' | Select-Object -First 1).LineNumber
        if (-not $startIdx) { $fails += 'Prediction file is missing the prediction section (## Prediction)' }
        else {
            $rest = $lines[$startIdx..($lines.Count-1)]
            $endRel = ($rest | Select-String -Pattern '^## ' | Select-Object -First 1).LineNumber
            if ($endRel) { $sec = $lines[($startIdx-1)..($startIdx+$endRel-3)] } else { $sec = $lines[($startIdx-1)..($lines.Count-1)] }
            $bytes = [Text.Encoding]::UTF8.GetBytes(($sec -join "`n"))
            $hash = ( ($sha = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)) | ForEach-Object { $_.ToString('x2') }) -join ''
            if ($hash -ne $locked) { $fails += "Prediction section hash mismatch — immutability broken, publishing blocked; hand it back to Trae" }
        }
    }
}

# 6. Frequency cap: at most 2 posts per day (reads today's entry in log.md)
$today = Get-Date -Format 'yyyy-MM-dd'
$logLines = Get-Content (Join-Path $root 'log.md') -Encoding UTF8
$todayCount = ($logLines | Select-String -Pattern "^## $today · post " | Measure-Object).Count
if ($todayCount -ge 2) { $fails += "Already published $todayCount posts today, hit the daily cap of 2" }

# 7. Frequency cap: at least 2h since the previous post (reads state last_published_at)
if ($state.last_published_at) {
    $last = [DateTime]::Parse($state.last_published_at)
    $hours = ((Get-Date) - $last).TotalHours
    if ($hours -lt 2) { $fails += "Only $([Math]::Round($hours,1))h since the last post, less than the 2h gap" }
}

# 8. Kill switch
$backlog = Get-Content (Join-Path $root 'backlog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($backlog.halt) { $fails += 'backlog.halt=true, global halt blocks publishing' }

# 9. Hard audio check (video notes): true loudness loudnorm I (LUFS) + true peak (dBTP) — see WORKFLOW.md 9.2
#    Not volumedetect's mean_volume: it averages silence into the mean, so narration with pauses is misjudged as out of range
if ($NoteType -eq 'video' -and $VideoPath) {
    $vFull = Join-Path $root $VideoPath
    # ffmpeg resolution: prefer $env:FFMPEG, then the real exe inside the local WinGet package (the ffmpeg.exe on PATH is a broken shim and will not run)
    $ff = $env:FFMPEG
    if (-not $ff -or -not (Test-Path $ff)) {
        $hit = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\ffmpeg.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        $ff = if ($hit) { $hit.FullName } else { 'ffmpeg' }
    }
    if (Test-Path $vFull) {
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $out = (& $ff -hide_banner -nostats -i $vFull -af loudnorm=print_format=json -f null - 2>&1 | Out-String)
        $ErrorActionPreference = $prev
        # Pull the two fields straight out of the loudnorm JSON (no full JSON parse: other { } in the ffmpeg output would confuse the regex)
        $mi = [regex]::Match($out, '"input_i"\s*:\s*"(-?[\d.]+)"')
        $mp = [regex]::Match($out, '"input_tp"\s*:\s*"(-?[\d.]+)"')
        if ($mi.Success -and $mp.Success) {
            $I  = [double]$mi.Groups[1].Value
            $tp = [double]$mp.Groups[1].Value
            $audioNote = "I=$I LUFS/TP=$tp dBTP"
            if ($tp -gt -1.0) { $fails += ("True peak {0} dBTP, must be ≤ -1.0 (clipping risk)" -f $tp) }
            if ($I -lt -30 -or $I -gt -14) { $fails += ("Loudness {0} LUFS out of range, must be -30..-14" -f $I) }
            elseif ($I -lt -20) { Write-Host ("[GATE-WARN] Loudness is quiet at {0} LUFS, consider loudnorm to about -16 LUFS" -f $I) }
        } else {
            $fails += 'Audio hard check could not run: ffmpeg unavailable or loudnorm produced no output (audio must be verifiable before publishing)'
        }
    }
}

if ($fails.Count -gt 0) {
    foreach ($f in $fails) { Write-Host "[GATE-FAIL] $f" }
    exit 1
}
Write-Host "[GATE-PASS] all checks green (NoteType=$NoteType): title $($Title.Length) chars / tags $TagsCount / video / $(if ($CoverPath) { 'cover 1080x1440' } else { 'no cover (first frame is the cover)' }) / prediction hash / $todayCount posts today / gap ${hours}h / no halt$(if ($audioNote) { ' / audio ' + $audioNote })"
exit 0
