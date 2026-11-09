<#
check.ps1 —— five-stage contract gate (improvement C) + master timeline coverage check (improvement B, script part)

Purpose: mechanically verify at every stage boundary that "the previous stage is final/complete", preventing "writing before things are final" and "delivering while broken".
Division of labour with tools\gate\validate.ps1: validate covers [publishing compliance], this script covers [stage contracts].

Usage (run from the repo root):
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/pipeline/check.ps1 `
      -ProjectDir videos/regular-ep09-reliability -Gate delivery

gate (how far to validate):
  pre-script  before writing script — only verifies that facts are final
  pre-code    before writing chapter code — verifies facts + script + outline (three elements / step counts match)
  pre-render  before rendering — also count conservation (C4) + audio (C6)
  delivery    before delivery/publishing — everything + timeline consistency (C5, strictest)
  media       media layer only — only count conservation (C4) + timeline (C5) + audio (C6), skipping the three text artifacts
              (for gh-daily lines whose root has no facts/script/outline)
  all         no stage gate; validate whatever files exist (default)

Switches:
  -SkipFacts    skip facts.md validation (for gh-daily lines that waive the research card)
  -Determinism  additionally run the frame-hash determinism check: the first run writes the baseline raw\shots.sha256, re-render and run again to compare

2026-10-19 changes:
  C7 (content usability) demoted from FAIL to WARN — content quality is now guarded by the skill's built-in QA mechanisms
    (SCRIPT-STYLE four-layer self-check + CHAPTER-CRAFT completion self-check); mechanical assertions are reminders only.
  C8 (persona red line) stays FAIL, not demoted.
  Added C9 visual elements: whether chapter tsx files reference concrete components/viz elements (WARN).
  Added C10 copy self-check evidence: script-selfcheck.md exists and covers the four-layer self-check
    (FAIL at the pre-code / pre-render / delivery gates).
2026-10-27 changes:
  Added C13 design-intent evidence: design-intent.md exists and is not a placeholder (**WARN only, does not block**,
    see WORKFLOW 8.4 "cheat → creation three-pass loop").

Exit codes: 0 = all green (WARN does not block); 1 = there are FAILs; 2 = argument/environment error
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ProjectDir,
  [ValidateSet('all', 'pre-script', 'pre-code', 'pre-render', 'delivery', 'media')]
  [string]$Gate = 'all',
  [switch]$SkipFacts,
  [switch]$Determinism
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$results = New-Object System.Collections.ArrayList
function Add-Result([string]$level, [string]$id, [string]$msg) {
  [void]$results.Add([pscustomobject]@{ Level = $level; Id = $id; Msg = $msg })
  $tag = @{ PASS = '[PASS]'; WARN = '[WARN]'; FAIL = '[FAIL]' }[$level]
  Write-Output ("{0} {1} {2}" -f $tag, $id, $msg)
}

# --- path resolution ---
try { $root = (Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop).Path }
catch { Write-Output "ERROR: ProjectDir does not exist: $ProjectDir"; exit 2 }
if (-not (Test-Path -LiteralPath $root -PathType Container)) { Write-Output "ERROR: not a directory: $root"; exit 2 }

$facts    = Join-Path $root 'facts.md'
$scriptMd = Join-Path $root 'script.md'
$outline  = Join-Path $root 'outline.md'
$beats    = Join-Path $root 'beats.json'
$pres     = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'presentation' } | Select-Object -First 1

$needFacts   = (-not $SkipFacts) -and ($Gate -in @('all', 'pre-script', 'pre-code', 'pre-render', 'delivery'))
$needScript  = $Gate -in @('all', 'pre-code', 'pre-render', 'delivery')
$needOutline = $Gate -in @('all', 'pre-code', 'pre-render', 'delivery')
$needMedia   = $Gate -in @('all', 'pre-render', 'delivery', 'media')
$strict      = $Gate -eq 'delivery'

function Read-Raw([string]$p) { if (Test-Path -LiteralPath $p) { Get-Content -LiteralPath $p -Raw -Encoding UTF8 } else { $null } }
function Count-Beats([string]$p) {
  # Split on '---' into blocks and only count blocks that contain real narration text
  # (skipping header blocks and blocks with only headings/quotes/blank lines), so the
  # horizontal rule under the header is not mistaken for a beat.
  $lines = Get-Content -LiteralPath $p -Encoding UTF8
  $blocks = New-Object System.Collections.ArrayList
  $cur = New-Object System.Collections.ArrayList
  foreach ($ln in $lines) {
    if ($ln.Trim() -eq '---') { [void]$blocks.Add($cur); $cur = New-Object System.Collections.ArrayList }
    else { [void]$cur.Add($ln) }
  }
  [void]$blocks.Add($cur)
  $n = 0
  foreach ($b in $blocks) {
    foreach ($ln in $b) {
      $t = $ln.Trim()
      if (($t -ne '') -and (-not $t.StartsWith('#')) -and (-not $t.StartsWith('>'))) { $n++; break }
    }
  }
  return $n
}
function Test-Placeholder([string]$text) {
  foreach ($t in @('TODO', 'TBD', 'FIXME', 'placeholder', 'xxxx')) {
    if ($text -match [regex]::Escape($t)) { return $t }
  }
  return $null
}

# --- C13 · design-intent evidence (added 2026-10-27, WARN only, does not block) ---
# Content judgement is not delegated to hard-coded rules: this only reminds that design-intent was actually written, without judging quality (see WORKFLOW 8.4).
if ($Gate -in @('all', 'pre-script', 'pre-code', 'pre-render', 'delivery')) {
  $diPath = Join-Path $root 'design-intent.md'
  if (-not (Test-Path -LiteralPath $diPath)) {
    Add-Result 'WARN' 'C13-design-intent' 'design-intent.md is missing (the three pre-creation questions were never saved, see WORKFLOW 8.4)'
  }
  else {
    $di = Read-Raw $diPath
    $diLen = if ($di) { $di.Trim().Length } else { 0 }
    $diPh = if ($di) { Test-Placeholder $di } else { $null }
    if ($diLen -lt 120) {
      Add-Result 'WARN' 'C13-design-intent' ("design-intent.md is too short ({0} characters); the three questions may not be answered concretely" -f $diLen)
    }
    elseif ($diPh) {
      Add-Result 'WARN' 'C13-design-intent' ("design-intent.md contains the placeholder '{0}', treating it as unfinished" -f $diPh)
    }
    else { Add-Result 'PASS' 'C13-design-intent' 'design-intent.md saved (three pre-creation questions)' }
  }
}

# --- C1 · facts final (stage 1) ---
if ($needFacts) {
  $f = Read-Raw $facts
  if (-not $f) {
    Add-Result 'FAIL' 'C1-facts-exists' "facts.md research card missing: $facts (no writing without solid research)"
  }
  else {
    $ph = Test-Placeholder $f
    if ($ph) { Add-Result 'FAIL' 'C1-facts-final' "facts.md contains the placeholder '$ph', treating it as not final" }
    else { Add-Result 'PASS' 'C1-facts-final' 'facts.md has no placeholders, treated as final' }
    if ($f -match '(?m)^#{2,3}\s*(?:\d+\s*\.\s*)?source') { Add-Result 'PASS' 'C1-sources' 'contains the source-list section' }
    else { Add-Result 'FAIL' 'C1-sources' 'facts.md is missing the source-list section (section 1, sources)' }
    if ($f -match '(?m)^#{2,3}\s*(?:\d+\s*\.\s*)?key[ -]?data') { Add-Result 'PASS' 'C1-data' 'contains the key-data-with-sources section' }
    else { Add-Result 'FAIL' 'C1-data' 'facts.md is missing the key-data-with-sources section (section 2, key data with sources)' }
  }
}

# --- C2 · script final (stage 2) ---
$beats_script = $null
if ($needScript) {
  $s = Read-Raw $scriptMd
  if (-not $s) { Add-Result 'FAIL' 'C2-script-exists' "script.md missing: $scriptMd" }
  else {
    $ph = Test-Placeholder $s
    if ($ph) { Add-Result 'FAIL' 'C2-script-final' "script.md contains the placeholder '$ph', treating it as not final" }
    else { Add-Result 'PASS' 'C2-script-final' 'script.md has no placeholders, treated as final' }
    $beats_script = Count-Beats $scriptMd
    if ($beats_script -ge 2) { Add-Result 'PASS' 'C2-beats' ("script.md beat count (--- separated) = {0}" -f $beats_script) }
    else { Add-Result 'FAIL' 'C2-beats' ("script.md beat count abnormal ({0}), expected ≥2" -f $beats_script) }
  }
}

# --- C3 · outline storyboard elements (stage 3) ---
if ($needOutline) {
  $o = Read-Raw $outline
  if (-not $o) { Add-Result 'FAIL' 'C3-outline-exists' "outline.md missing: $outline" }
  else {
    $lines = Get-Content -LiteralPath $outline -Encoding UTF8
    $chapN = 0; $stepSum = 0; $missing = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^##\s+\S+.*\|\s*(\d+)\s*steps?') {
        $chapN++; $stepSum += [int]$Matches[1]
        $hdr = $null
        for ($j = $i + 1; $j -lt [Math]::Min($i + 15, $lines.Count); $j++) {
          if ($lines[$j] -match '^\|\s*step\s*\|') { $hdr = $lines[$j]; break }
        }
        if ((-not $hdr) -or ($hdr -notmatch 'transition') -or ($hdr -notmatch 'visual focus') -or ($hdr -notmatch 'protection')) {
          $missing += $lines[$i].Trim()
        }
      }
    }
    if ($chapN -eq 0) { Add-Result 'FAIL' 'C3-sections' 'outline.md has no "## <title> | N steps" chapter declarations' }
    else { Add-Result 'PASS' 'C3-sections' ("outline.md has {0} chapters declaring {1} steps in total" -f $chapN, $stepSum) }
    if ($missing.Count -eq 0) { Add-Result 'PASS' 'C3-three-elems' 'every chapter header has the three elements: transition / visual focus / protection' }
    else { Add-Result 'FAIL' 'C3-three-elems' ("these chapter headers lack the three elements: " + ($missing -join ' | ')) }
    if ($beats_script -and ($stepSum -ne $beats_script)) {
      Add-Result 'FAIL' 'C3-steps-match' ("outline steps({0}) ≠ script beats({1})" -f $stepSum, $beats_script)
    }
    elseif ($beats_script) {
      Add-Result 'PASS' 'C3-steps-match' ("outline steps == script beats == {0}" -f $stepSum)
    }
  }
}

# --- C4 · count conservation (stages 4/5) ---
if ($needMedia) {
  if (-not $pres) { Add-Result 'FAIL' 'C4-pres' "no web project directory containing 'presentation' found" }
  else {
    $pp = $pres.FullName
    $n_narr = 0
    foreach ($nf in @(Get-ChildItem -LiteralPath (Join-Path $pp 'src\chapters') -Recurse -Filter 'narrations.ts' -ErrorAction SilentlyContinue)) {
      $n_narr += @(Get-Content -LiteralPath $nf.FullName -Encoding UTF8 | Where-Object { $_.Trim() -match '^"' }).Count
    }
    $segPath = Join-Path $pp 'audio-segments.json'
    $n_seg = if (Test-Path $segPath) { @((Get-Content -LiteralPath $segPath -Raw -Encoding UTF8 | ConvertFrom-Json)).Count } else { $null }
    $n_mp3 = @(Get-ChildItem -LiteralPath (Join-Path $pp 'public\audio') -Recurse -Filter '*.mp3' -ErrorAction SilentlyContinue).Count
    $n_beats = if (Test-Path $beats) { @((Get-Content -LiteralPath $beats -Raw -Encoding UTF8 | ConvertFrom-Json)).Count } else { $null }

    $ref = if ($beats_script) { $beats_script } else { $n_narr }
    $bad = @()
    foreach ($p in @(
        @{ n = 'narrations entries'; v = $n_narr },
        @{ n = 'audio-segments entries'; v = $n_seg },
        @{ n = 'public/audio mp3 count'; v = $n_mp3 },
        @{ n = 'beats.json entries'; v = $n_beats })) {
      if (($null -ne $p.v) -and ($p.v -ne $ref)) { $bad += ("{0}={1}" -f $p.n, $p.v) }
    }
    if ($bad.Count -eq 0) { Add-Result 'PASS' 'C4-counts' ("count conservation: all == {0}" -f $ref) }
    else { Add-Result 'FAIL' 'C4-counts' ("counts not conserved (baseline {0}): {1}" -f $ref, ($bad -join '; ')) }
    if ($null -eq $n_seg) { Add-Result ($(if ($strict) { 'FAIL' } else { 'WARN' })) 'C4-seg' 'audio-segments.json missing' }
    if ($null -eq $n_beats) { Add-Result ($(if ($strict) { 'FAIL' } else { 'WARN' })) 'C4-beats' 'beats.json missing' }
  }
}

# --- C5 · timeline consistency / master timeline coverage (stage 4) ---
if ($needMedia -and $pres) {
  $pp = $pres.FullName
  if (Test-Path $beats) {
    $bj = @((Get-Content -LiteralPath $beats -Raw -Encoding UTF8 | ConvertFrom-Json))
    $errs = @()
    foreach ($b in $bj) {
      foreach ($k in @('step_id', 'chapter', 'step', 'start_ms', 'dur_ms', 'text')) {
        if (-not ($b.PSObject.Properties.Name -contains $k)) { $errs += ("{0}.{1} missing" -f $b.step_id, $k) }
      }
      if ($b.dur_ms -le 0) { $errs += ("{0}.dur_ms<=0" -f $b.step_id) }
    }
    if ($errs.Count -eq 0) { Add-Result 'PASS' 'C5-beats-schema' 'beats.json fields complete, dur_ms>0' }
    else { Add-Result 'FAIL' 'C5-beats-schema' ("beats.json invalid: " + ($errs -join ', ')) }

    $marksPath = Join-Path $pp 'raw\marks.json'
    if (Test-Path $marksPath) {
      $mj = Get-Content -LiteralPath $marksPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $markIds = @($mj.marks | ForEach-Object { $_.id })
      $missing = @($bj | ForEach-Object { $_.step_id } | Where-Object { $markIds -notcontains $_ })
      if ($missing.Count -eq 0) { Add-Result 'PASS' 'C5-marks-cover' ("marks.json (master timeline) covers all {0} steps" -f $bj.Count) }
      else { Add-Result 'FAIL' 'C5-marks-cover' ("marks.json is missing {0} steps: {1}" -f $missing.Count, ($missing -join ',')) }
    }
    else { Add-Result 'WARN' 'C5-marks-cover' 'raw\marks.json not kept (cleaning raw\ after rendering is normal), cannot verify frame coverage' }

    $shotsDir = Join-Path $pp 'raw\shots'
    if (Test-Path $shotsDir) {
      $n_shot = @(Get-ChildItem -LiteralPath $shotsDir -Filter '*.png').Count
      if ($n_shot -eq $bj.Count) { Add-Result 'PASS' 'C5-shots' ("raw\shots frame count({0}) == beats steps" -f $n_shot) }
      else { Add-Result 'FAIL' 'C5-shots' ("raw\shots frame count({0}) ≠ beats steps({1})" -f $n_shot, $bj.Count) }
    }
    else { Add-Result 'WARN' 'C5-shots' 'raw\shots not kept, cannot verify frame coverage' }
  }
}

# --- C6 · audio exists and is non-empty (stage 5) ---
if ($needMedia -and $pres) {
  $pp = $pres.FullName
  $segPath = Join-Path $pp 'audio-segments.json'
  if (Test-Path $segPath) {
    $segs = @((Get-Content -LiteralPath $segPath -Raw -Encoding UTF8 | ConvertFrom-Json))
    $missing = @(); $empty = @()
    foreach ($sg in $segs) {
      $af = Join-Path (Join-Path $pp 'public\audio') ($sg.audio -replace '/', '\')
      if (-not (Test-Path -LiteralPath $af)) { $missing += $sg.audio }
      elseif ((Get-Item -LiteralPath $af).Length -lt 2048) { $empty += $sg.audio }
    }
    if (($missing.Count -eq 0) -and ($empty.Count -eq 0)) { Add-Result 'PASS' 'C6-audio' ("all {0} audio segments exist and are non-empty" -f $segs.Count) }
    else {
      if ($missing.Count) { Add-Result 'FAIL' 'C6-audio-missing' ("missing audio files: " + (($missing | Select-Object -First 5) -join ', ')) }
      if ($empty.Count) { Add-Result 'FAIL' 'C6-audio-empty' ("audio too small (likely empty/silent): " + (($empty | Select-Object -First 5) -join ', ')) }
    }
  }
  else { Add-Result ($(if ($strict) { 'FAIL' } else { 'WARN' })) 'C6-audio' 'no audio-segments.json, skipping audio verification' }
}

# --- C7 · content usability (added 2026-10-18, targets "bad content"; fully mechanical, no AI judgement) ---
# Background: C1~C6 only verify craft (finalized / count conservation / timeline / audio); a bad script can pass all green.
# C7 adds the "can the audience understand it" layer: teaching-design section + closing payoff + hook loop + first-use term explanations.
#
# [2026-10-19 adjustment] C7 demoted from FAIL to WARN — the user ruled that content quality **must not be constrained
# by hard-coded rules**, and is guarded by the skill's built-in QA mechanisms (SCRIPT-STYLE four-layer self-check +
# CHAPTER-CRAFT completion self-check); mechanical assertions remain as reminders only. Persona red line C8 stays FAIL (red lines are not demoted).
$c7 = 'WARN'
if ($needFacts) {
  $f = Read-Raw $facts
  if ($f) {
    $sect = $null
    if ($f -match '(?ms)^#{2,3}[^\r\n]*(?:teaching design|instructional design)[^\r\n]*\r?\n(.*?)(?=^#{1,3}\s|\z)') { $sect = $Matches[1] }
    if (-not $sect) {
      Add-Result $c7 'C7-facts-design' 'facts.md is missing the teaching-design section (facts must not be a bare fact ledger; it must include how it is taught)'
    }
    else {
      $miss = @()
      foreach ($it in @(
          @{ n = 'teaching goal';     p = 'teaching goal|learning objective' },
          @{ n = 'audience prior assumptions'; p = 'viewer prior assumptions|assumed audience background|prior assumptions|audience background' },
          @{ n = 'example context';   p = 'context' },
          @{ n = 'experience translation';     p = 'experience translation|experience' },
          @{ n = 'argument chain / narrative arc'; p = 'argument chain|narrative arc' },
          @{ n = 'closing payoff';     p = 'ending landing point|landing point|actionable advice|payoff' })) {
        if ($sect -notmatch $it.p) { $miss += $it.n }
      }
      if ($miss.Count -eq 0) { Add-Result 'PASS' 'C7-facts-design' 'teaching-design section has all 6 sub-items (goal / priors / example context / experience translation / argument chain / payoff)' }
      else { Add-Result $c7 'C7-facts-design' ("teaching-design section is missing sub-items: " + ($miss -join ', ')) }
    }
  }
}
if ($needScript) {
  $s = Read-Raw $scriptMd
  if ($s) {
    $bt = New-Object System.Collections.ArrayList
    $cur = New-Object System.Collections.ArrayList
    foreach ($ln in (Get-Content -LiteralPath $scriptMd -Encoding UTF8)) {
      if ($ln.Trim() -eq '---') { [void]$bt.Add($cur); $cur = New-Object System.Collections.ArrayList }
      else { [void]$cur.Add($ln) }
    }
    [void]$bt.Add($cur)
    $texts = @()
    foreach ($b in $bt) {
      $t = ''
      foreach ($ln in $b) {
        $x = $ln.Trim()
        if (($x -ne '') -and (-not $x.StartsWith('#')) -and (-not $x.StartsWith('>'))) { $t += $x }
      }
      if ($t -ne '') { $texts += $t }
    }
    $n = $texts.Count

    # C7a · closing payoff: the last 2 beats must contain an actionable/conclusive sentence (the audience must know what to do)
    $tail2 = ($texts | Select-Object -Last 2) -join ' '
    if (($n -ge 2) -and ($tail2 -match 'you can|you should|recommend|suggest|remember|set .{0,25}to|try|next time|if you|push .{0,25}to|turn .{0,25}to|add a|rerun|ask for|stick to|back to|in your hands')) {
      Add-Result 'PASS' 'C7a-ending-action' 'closing contains an actionable/conclusive sentence'
    } else {
      Add-Result $c7 'C7a-ending-action' 'the last 2 beats have no actionable advice (the audience will not know what to do)'
    }

    # C7b · hook loop: the question raised in the first beat must be answered in the last 3 beats
    $head  = $texts[0]
    $tail3 = ($texts | Select-Object -Last 3) -join ' '
    if ($head -match 'why|does|do you|is it|same|always|ever|but|yet|still|differ|different|reverse') {
      if ($tail3 -match 'so|that is why|that.s why|back to|reason|at the start|in the beginning|the point|actually|which is why') { Add-Result 'PASS' 'C7b-hook-loop' 'the hook has a payoff sentence, the suspense closes' }
      else { Add-Result $c7 'C7b-hook-loop' 'the event raised by the first-beat hook is never resolved at the end (suspense left hanging)' }
    } else {
      Add-Result 'WARN' 'C7b-hook-loop' 'no hook question detected in the first beat, skipping the loop check'
    }

    # C7c · a term must be explained on first appearance (for zero-prior audience)
    $termMiss = @()
    foreach ($term in @(
        @{ n = 'Temperature'; p = 'Temperature' },
        @{ n = 'Top P';       p = 'Top[ -]?P' },
        @{ n = 'logit';       p = 'logit' },
        @{ n = 'softmax';     p = 'softmax' })) {
      $idx = -1
      for ($i = 0; $i -lt $n; $i++) { if ($texts[$i] -match $term.p) { $idx = $i; break } }
      if ($idx -ge 0) {
        if ($texts[$idx] -notmatch 'means|meaning|that is|in other words|basically|literally|called|refers to|stands for|which is|is the') { $termMiss += $term.n }
      }
    }
    if ($termMiss.Count -eq 0) { Add-Result 'PASS' 'C7c-term-explain' 'every term is explained where it first appears' }
    else { Add-Result $c7 'C7c-term-explain' ("these terms are not explained on first appearance: " + ($termMiss -join ', ') + ' (a zero-prior audience will not follow)') }
  }
}

# --- C8 · persona red-line scan (added 2026-10-18, targets "invented personal experience"; fully mechanical, no AI judgement) ---
# Rule: when script.md contains first-person experience claims (I stepped in it / I measured / I built / I tried / I ran ...),
#       facts.md must contain the evidence-list section and itemize the real record behind each claim (date/file/source).
#       A missing section or uncovered claims is FAIL — matching account.md red line "never invent personal experience or measured data".
if ($needScript) {
  $s8 = Read-Raw $scriptMd
  if ($s8) {
    $claimPat = '(?i)I\s+(?:tried|tested|measured|built|ran|used|walked|stepped|wrote|made|did|debugged|deployed|broke)|I.ve\s+(?:tried|tested|measured|built|run|used|done)|I\s+have\s+(?:tried|tested|measured|built|run|used|done)|I\s+myself'
    $claimTags = New-Object System.Collections.ArrayList
    foreach ($ln in (Get-Content -LiteralPath $scriptMd -Encoding UTF8)) {
      $t = $ln.Trim()
      if (($t -eq '') -or ($t.StartsWith('#')) -or ($t.StartsWith('>'))) { continue }
      foreach ($m in [regex]::Matches($t, $claimPat)) {
        $tag = $m.Value
        if ($claimTags -notcontains $tag) { [void]$claimTags.Add($tag) }
      }
    }
    if ($claimTags.Count -eq 0) {
      Add-Result 'PASS' 'C8-persona-claims' 'script has no first-person experience claims, no fabrication risk'
    }
    else {
      $f8 = Read-Raw $facts
      if (-not $f8) {
        Add-Result 'FAIL' 'C8-persona-claims' ("script contains first-person experience claims ({0}), but facts.md is missing so they cannot be verified" -f ($claimTags -join '/'))
      }
      else {
        $sec8 = $null
        if ($f8 -match '(?ms)^#{2,3}[^\r\n]*(?:evidence list)[^\r\n]*\r?\n(.*?)(?=^#{1,3}\s|\z)') { $sec8 = $Matches[1] }
        if (-not $sec8) {
          Add-Result 'FAIL' 'C8-persona-claims' ("script contains first-person experience claims ({0}), but facts.md has no evidence-list section → suspected fabrication of personal experience" -f ($claimTags -join '/'))
        }
        else {
          $unbacked = @($claimTags | Where-Object { $sec8 -notmatch [regex]::Escape($_) })
          if ($unbacked.Count -eq 0) { Add-Result 'PASS' 'C8-persona-claims' ("the evidence list covers every first-person claim: {0}" -f ($claimTags -join '/')) }
          else { Add-Result 'FAIL' 'C8-persona-claims' ("these first-person experience claims have no evidence record: {0} (red line: never invent personal experience)" -f ($unbacked -join '/')) }
        }
      }
    }
  }
}

# --- C9 · visual elements (added 2026-10-19, targets "empty visuals / content covers only 1/3 of the screen"; WARN, does not block) ---
# Rule: each chapter tsx must reference at least 1 concrete components/viz element (show what you talk about).
# Only the mechanical "is it used" check; semantic judgements such as "≥1 per step + relevant to the narration + main visual ≥55% in the middle"
# are left to the CHAPTER-CRAFT.md completion self-check (human/AI review).
if ($needOutline -and $pres) {
  $chapDir = Join-Path $pres.FullName 'src\chapters'
  if (Test-Path -LiteralPath $chapDir) {
    $tsx = @(Get-ChildItem -LiteralPath $chapDir -Recurse -Filter '*.tsx' -ErrorAction SilentlyContinue)
    $noViz = @()
    foreach ($t in $tsx) {
      $raw = Get-Content -LiteralPath $t.FullName -Raw -Encoding UTF8
      if ($raw -notmatch 'components/viz') { $noViz += $t.Name }
    }
    if ($tsx.Count -eq 0) { Add-Result 'WARN' 'C9-viz' 'no chapter tsx under src\chapters, cannot verify visual elements' }
    elseif ($noViz.Count -eq 0) { Add-Result 'PASS' 'C9-viz' ("all {0} chapters reference concrete components/viz elements" -f $tsx.Count) }
    else { Add-Result 'WARN' 'C9-viz' ("these chapters do not reference concrete components/viz elements (visuals may be empty): " + ($noViz -join ', ')) }
  }
}

# --- C10 · copy self-check evidence (added 2026-10-19, targets "bad copy") ---
# Rule: Phase 1 must complete SCRIPT-STYLE.md's four-layer self-check (form / soul / read-aloud / structure)
#       → revise → save script-selfcheck.md as evidence. Enforced from pre-code onward.
if ($Gate -in @('pre-code', 'pre-render', 'delivery')) {
  $sc = Join-Path $root 'script-selfcheck.md'
  if (Test-Path -LiteralPath $sc) {
    $scRaw = Read-Raw $sc
    if (($scRaw -match '\bform\b') -and ($scRaw -match 'substance layer|character layer|substance') -and ($scRaw -match 'read[\s-]*(?:it[\s-]*)?aloud') -and ($scRaw -match '\bstructure\b')) {
      # 2026-10-31 tightened: the four-layer self-check only proves "the form was gone through"; the opening three elements and
      # the blind-read retelling must leave per-item verdicts, otherwise there is no way to tell "really read it" from
      # "just wrote four headings" (ep11 failed on the opening four revisions in a row, see SCRIPT-STYLE item 7).
      $hasElements = ($scRaw -match 'three elements|opening three') -and ($scRaw -match '(?m)^.*PASS|MISSING')
      $hasBlind = ($scRaw -match 'blind[\s-]*read')
      if ($hasElements -and $hasBlind) {
        Add-Result 'PASS' 'C10-script-selfcheck' 'script-selfcheck.md covers the four-layer self-check + per-item opening three-elements verdict + blind-read retelling'
      }
      else {
        $miss = @()
        if (-not $hasElements) { $miss += 'per-item opening three-elements verdict (who / what happens / why worth watching, each marked PASS or MISSING)' }
        if (-not $hasBlind) { $miss += 'blind-read retelling record (including item 5, the opening three elements)' }
        Add-Result 'FAIL' 'C10-script-selfcheck' ("script-selfcheck.md is missing: " + ($miss -join '; '))
      }
    }
    else { Add-Result 'FAIL' 'C10-script-selfcheck' 'script-selfcheck.md does not cover the four-layer self-check (form / soul / read-aloud / structure), counted as not completed' }
  }
  else { Add-Result 'FAIL' 'C10-script-selfcheck' 'script-selfcheck.md missing: Phase 1 did not record the SCRIPT-STYLE four-layer self-check (must not enter Phase 2)' }
}

# --- C14 · duration estimate (added 2026-10-31; WARN) ---
# Background: a 591-character script estimated at 3.3 chars/s → 179s, but the actual TTS render was 153.3s (13 beats × 1.5s dwell).
# Measured speech rate is close to 4 chars/s, so the character-count formula must use the measured value, otherwise every episode is systematically short/long.
# Criterion: est = CJK characters / 4.0 + beats × 1.5; target band 120–180s, outside only WARN, does not block.
if ($Gate -in @('pre-code', 'pre-render', 'delivery')) {
  if (Test-Path -LiteralPath $scriptMd) {
    $body = (Get-Content -LiteralPath $scriptMd -Encoding UTF8 | Where-Object {
        $t = $_.Trim(); ($t -ne '') -and (-not $t.StartsWith('#')) -and (-not $t.StartsWith('>'))
      }) -join "`n"
    $cjk = ([regex]::Matches($body, '[\u4e00-\u9fff]')).Count
    $words = ([regex]::Matches($body, "[A-Za-z][A-Za-z'-]*")).Count
    $beats = ([regex]::Matches($body, '(?m)^---$')).Count + 1
    # A script is "Chinese" when CJK characters outnumber Latin words; a few stray CJK
    # characters inside an English script must not flip the estimator.
    # English fallback: 2.8 words/s ≈ 168 wpm, close to the default rate of neural TTS.
    $est = 0; $basis = ''
    if ($cjk -gt $words) {
      $est = [math]::Round($cjk / 4.0 + $beats * 1.5, 0)
      $basis = "${cjk} chars / ${beats} beats; formula = chars/4 + beats×1.5"
    }
    elseif ($words -gt 0) {
      $est = [math]::Round($words / 2.8 + $beats * 1.5, 0)
      $basis = "${words} words / ${beats} beats; formula = words/2.8 + beats×1.5 (English)"
    }
    if ($est -gt 0) {
      if (($est -lt 120) -or ($est -gt 180)) {
        Add-Result 'WARN' 'C14-duration' ("estimated $est s ($basis) outside the 120–180s target band")
      }
      else { Add-Result 'PASS' 'C14-duration' "estimated $est s ($basis) within the target band" }
    }
  }
}

# --- C15 · ledger JSON integrity (added 2026-10-31; FAIL) ---
# Background: hand-editing backlog/.cheat-state left trailing commas twice, crashing the CLI at startup and wasting a whole run.
if ($Gate -in @('all', 'pre-script', 'pre-code', 'pre-render', 'delivery')) {
  $rootDir = $root
  for ($i = 0; $i -lt 3; $i++) {
    if (Test-Path -LiteralPath (Join-Path $rootDir 'backlog.json')) { break }
    $rootDir = Split-Path -Parent $rootDir
  }
  foreach ($jf in @('backlog.json', '.cheat-state.json')) {
    $jp = Join-Path $rootDir $jf
    if (Test-Path -LiteralPath $jp) {
      try {
        $null = (Get-Content -LiteralPath $jp -Raw -Encoding UTF8 | ConvertFrom-Json)
        Add-Result 'PASS' 'C15-json' "$jf parsed successfully"
      }
      catch { Add-Result 'FAIL' 'C15-json' "$jf is not valid JSON: $($_.Exception.Message)" }
    }
  }
}

# --- C11 · narration script structure (added 2026-10-19, targets "structure falls apart"; effective for pre-code / pre-render / delivery) ---
# Background: a script whose wording all passes but whose structure falls apart still loses the audience (ep08 failed here, see SCRIPT-STYLE section 5).
# Three mechanical assertions:
#   C11-seq  classification-tree consistency — the same level must not mix classifier units (road/kind/class/tier), and numbering must not skip.
#   C11-list enumerated items — saying "N items" requires listing all N items, not just the number.
#   C11-term explain on first appearance — the beat where a term first appears must contain its keywords within the next 40 characters (table in terminology.txt).
# [tightening note 2026-10-19] the first version of C11-list produced many false positives on valid scripts (the generic classifier, "two things",
#   examples inside quotes were all matched); it is now tightened to: only the item/entry/kind/step/pitfall classifiers, N≥3, skip quoted examples,
#   so ep08 is caught while ep07/06/05/04 stay clean (see the regression report).
if ($Gate -in @('pre-code', 'pre-render', 'delivery')) {
  $sRaw = Read-Raw $scriptMd
  if ($sRaw) {
    # Body lines (drop headings/quotes/rules), flattened into a whitespace-free string so windows can be cut by "characters"
    $bl = New-Object System.Collections.ArrayList
    foreach ($ln in (Get-Content -LiteralPath $scriptMd -Encoding UTF8)) {
      $t = $ln.Trim()
      if (($t -eq '') -or $t.StartsWith('#') -or $t.StartsWith('>') -or ($t -match '^[-*_]{3,}$')) { continue }
      [void]$bl.Add($t)
    }
    $body = ($bl -join '') -replace '\s+', ''

    # Per-beat (--- separated) body text, so C11-term can locate "the beat of first appearance"
    $bt = New-Object System.Collections.ArrayList
    $cur = New-Object System.Collections.ArrayList
    foreach ($ln in (Get-Content -LiteralPath $scriptMd -Encoding UTF8)) {
      if ($ln.Trim() -eq '---') { [void]$bt.Add($cur); $cur = New-Object System.Collections.ArrayList }
      else { [void]$cur.Add($ln) }
    }
    [void]$bt.Add($cur)
    $beatTexts = @()
    foreach ($b in $bt) {
      $t = ''
      foreach ($ln in $b) {
        $x = $ln.Trim()
        if (($x -eq '') -or $x.StartsWith('#') -or $x.StartsWith('>')) { continue }
        $t += ($x -replace '\s+', '')
      }
      if ($t -ne '') { $beatTexts += $t }
    }

    $numMap = @{ 'one' = 1; 'two' = 2; 'three' = 3; 'four' = 4; 'five' = 5; 'six' = 6; 'seven' = 7; 'eight' = 8; 'nine' = 9; 'ten' = 10; 'first' = 1; 'second' = 2; 'third' = 3; 'fourth' = 4; 'fifth' = 5; 'sixth' = 6; 'seventh' = 7; 'eighth' = 8; 'ninth' = 9; 'tenth' = 10 }
    function Convert-CnNum([string]$w) {
      if ($w -match '^\d+$') { return [int]$w }
      $k = $w.ToLowerInvariant()
      if ($numMap.ContainsKey($k)) { return [int]$numMap[$k] }
      return -1
    }

    # ---- C11-seq numbering consistency ----
    $seqHits = @([regex]::Matches($body, '(?i)(?:the\s*)?(\d+|one|two|three|four|five|six|seven|eight|nine|ten|first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\s*(road|kind|class|tier|type)'))
    if ($seqHits.Count -eq 0) {
      Add-Result 'PASS' 'C11-seq' 'no "Nth + road/kind/class/tier" classifier numbering found, skipping'
    }
    else {
      $seqErrs = @()
      $hasLu  = @($seqHits | Where-Object { @('road') -contains $_.Groups[2].Value }).Count -gt 0
      $hasAlt = @($seqHits | Where-Object { @('kind', 'class', 'type', 'tier') -contains $_.Groups[2].Value }).Count -gt 0
      if ($hasLu -and $hasAlt) {
        $seqErrs += ('mixed classifier units at the same level (road vs kind/class): ' + (($seqHits | ForEach-Object { $_.Value }) -join ' / '))
      }
      foreach ($g in ($seqHits | Group-Object { $_.Groups[2].Value })) {
        $nums = @($g.Group | ForEach-Object { Convert-CnNum $_.Groups[1].Value } | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
        if ($nums.Count -ge 2) {
          $missing = @()
          for ($v = $nums[0]; $v -le $nums[-1]; $v++) { if ($nums -notcontains $v) { $missing += $v } }
          if ($missing.Count -gt 0) { $seqErrs += ('numbering skips values in the "' + $g.Name + '" series; missing: ' + ($missing -join ',')) }
        }
      }
      if ($seqErrs.Count -eq 0) { Add-Result 'PASS' 'C11-seq' ('classifier units/numbering self-consistent ({0} numbered spots)' -f $seqHits.Count) }
      else { Add-Result 'FAIL' 'C11-seq' ('classification-tree numbering inconsistent: ' + ($seqErrs -join ' | ')) }
    }

    # ---- C11-list enumerated items (tightened version) ----
    $bodyNoQ = [regex]::Replace($body, '"[^"]*"', '')
    $listHits = @([regex]::Matches($bodyNoQ, '(?i)(?<!\d)(\d+|three|four|five|six|seven|eight|nine|ten)\s*(items?|things?|steps?|kinds?|types?|pitfalls?|traps?)') | Where-Object { (Convert-CnNum $_.Groups[1].Value) -ge 3 })
    $listErrs = @()
    foreach ($m in $listHits) {
      $N = Convert-CnNum $m.Groups[1].Value
      $st = $m.Index + $m.Length
      $win = if ($st -lt $bodyNoQ.Length) { $bodyNoQ.Substring($st, [Math]::Min(60, $bodyNoQ.Length - $st)) } else { '' }
      $immediate = ($win.Length -gt 0) -and $win.StartsWith(':')
      $sepCount = ([regex]::Matches($win, ',')).Count
      if ((-not $immediate) -and ($sepCount -lt ($N - 1))) {
        $listErrs += ('claims {0} items but does not list them (at "{1}")' -f $N, $m.Value)
      }
    }
    if ($listHits.Count -eq 0) { Add-Result 'PASS' 'C11-list' 'no numbered claim requiring an item list found, skipping' }
    elseif ($listErrs.Count -eq 0) { Add-Result 'PASS' 'C11-list' ('all {0} numbered claims list their items' -f $listHits.Count) }
    else { Add-Result 'FAIL' 'C11-list' ('numbered claims without item lists: ' + ($listErrs -join ' | ')) }

    # ---- C11-term explain on first appearance ----
    $termPath = Join-Path $PSScriptRoot 'terminology.txt'
    if (-not (Test-Path -LiteralPath $termPath)) {
      $defTerms = "harness`tloop|looping|the loop code`r`nDOM`tskeleton|raw skeleton|page structure`r`naccessibility tree`tscreen reader|screen-reader`r`nprompt injection`tinstruction|command`r`nAPI`tinterface|endpoint"
      Set-Content -LiteralPath $termPath -Value $defTerms -Encoding UTF8
    }
    $termChecked = 0; $termErrs = @()
    foreach ($tl in (Get-Content -LiteralPath $termPath -Encoding UTF8)) {
      $line = $tl.Trim()
      if (($line -eq '') -or $line.StartsWith('#')) { continue }
      $parts = $line -split "`t", 2
      if ($parts.Count -lt 2) { continue }
      $term = $parts[0].Trim()
      $kws = @($parts[1].Split('|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
      if (($term -eq '') -or ($kws.Count -eq 0)) { continue }
      foreach ($bexp in $beatTexts) {
        $idx = $bexp.IndexOf($term, [System.StringComparison]::Ordinal)
        if ($idx -lt 0) { continue }
        $termChecked++
        $ts = $idx + $term.Length
        $win = if ($ts -lt $bexp.Length) { $bexp.Substring($ts, [Math]::Min(40, $bexp.Length - $ts)) } else { '' }
        $hit = $false
        foreach ($kw in $kws) { if ($win.Contains($kw)) { $hit = $true; break } }
        if (-not $hit) { $termErrs += ('{0} has no explanation within 40 characters after first appearance (keywords: {1})' -f $term, ($kws -join '/')) }
        break
      }
    }
    if ($termChecked -eq 0) { Add-Result 'PASS' 'C11-term' 'none of the terms listed in the terminology table appear in the script, skipping' }
    elseif ($termErrs.Count -eq 0) { Add-Result 'PASS' 'C11-term' ('all {0} appearing terms are explained on first appearance' -f $termChecked) }
    else { Add-Result 'FAIL' 'C11-term' ('terms not explained on first appearance: ' + ($termErrs -join ' | ')) }
  }
}

# --- C12 · PowerShell script BOM normalization (added 2026-10-19) ---
# Background: the editor appends one BOM to .ps1 on every save, and stacked BOMs make Windows PowerShell 5.1
#   fail to parse (Unexpected token); conversely no BOM makes comments be read as ANSI garbage. Rule: **exactly 1 BOM**.
#   Fix: powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\normalize-bom.ps1
$projRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$psFiles = @(Get-ChildItem -LiteralPath $projRoot -Recurse -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|cache|videos|\.venv)\\' })
$badBom = @()
foreach ($f in $psFiles) {
  $bb = [System.IO.File]::ReadAllBytes($f.FullName)
  $bn = 0
  while (($bn + 2) -lt $bb.Length -and $bb[$bn] -eq 0xEF -and $bb[$bn + 1] -eq 0xBB -and $bb[$bn + 2] -eq 0xBF) { $bn += 3 }
  if ($bn -ne 3) { $badBom += ("{0}(BOM={1})" -f $f.Name, $bn) }
}
if ($badBom.Count -eq 0) { Add-Result 'PASS' 'C12-bom' ("all {0} .ps1 files have a single BOM" -f $psFiles.Count) }
else { Add-Result 'FAIL' 'C12-bom' ('BOM not normalized (should be exactly 1; run tools\pipeline\normalize-bom.ps1 to fix): ' + ($badBom -join ', ')) }

# --- D1 · determinism check (-Determinism, improvement B) ---
if ($Determinism -and $pres) {
  $pp = $pres.FullName
  $shotsDir = Join-Path $pp 'raw\shots'
  $manifest = Join-Path $pp 'raw\shots.sha256'
  if (-not (Test-Path $shotsDir)) { Add-Result 'WARN' 'D1' 'raw\shots does not exist, cannot run the determinism check (render first, then run with -Determinism)' }
  else {
    $cur = Get-ChildItem -LiteralPath $shotsDir -Filter '*.png' | Sort-Object Name | ForEach-Object {
      "{0}  {1}" -f $_.Name, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    if (Test-Path $manifest) {
      $old = Get-Content -LiteralPath $manifest -Encoding UTF8
      $diff = Compare-Object $old $cur
      if (-not $diff) { Add-Result 'PASS' 'D1' 'frame hashes match across two renders → deterministic (no gacha)' }
      else { Add-Result 'FAIL' 'D1' ("frame hashes differ across two renders → output is non-deterministic ({0} differences)" -f @($diff).Count) }
    }
    else {
      $cur | Set-Content -LiteralPath $manifest -Encoding UTF8
      Add-Result 'WARN' 'D1' "first run: baseline hashes written to raw\shots.sha256 (render again and re-run this check to compare)"
    }
  }
}

# --- summary ---
$nPass = @($results | Where-Object { $_.Level -eq 'PASS' }).Count
$nWarn = @($results | Where-Object { $_.Level -eq 'WARN' }).Count
$nFail = @($results | Where-Object { $_.Level -eq 'FAIL' }).Count
$code = if ($nFail -gt 0) { 1 } else { 0 }
Write-Output ("RESULT: project={0} gate={1} pass={2} warn={3} fail={4} EXIT={5}" -f (Split-Path $root -Leaf), $Gate, $nPass, $nWarn, $nFail, $code)
exit $code
