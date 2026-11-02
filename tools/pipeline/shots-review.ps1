<#
shots-review.ps1 —— 抽帧目检脚手架（2026-10-18 新增）

用途：补文本级闸门（check.ps1）"读不懂画面"的盲区。按 master timeline（marks.json）逐拍
      抽取画面帧，生成【人工目检清单】，供核对机器查不出的语义问题：
      ① 图表数值与标注是否一致 ② 每拍信息量是否足够 ③ 例子的来源/出处是否标注
      ④ 钩子是否在结尾回收、章节衔接是否成立 ⑤ 留白与节奏。
      （诞生于 ep06 复盘：柱状图只渲染首柱、后半程四拍纯文字卡、图注未标来源——全部穿透 check.ps1）

用法（在仓库根目录下运行）：
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/pipeline/shots-review.ps1 `
      -ProjectDir videos/regular-ep09-reliability

输出（默认写临时区，不污染项目目录）：
  帧图 + shots-review.md → %TEMP%\shots-review\<ep>\      （-OutDir 可改）

退出码：0 = 生成成功；2 = 参数/环境错误（找不到视频 / marks.json / 无可用 ffmpeg）
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
catch { Write-Output "ERROR: ProjectDir 不存在: $ProjectDir"; exit 2 }
$ep   = Split-Path $root -Leaf
$pres = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'presentation' } | Select-Object -First 1

# --- 视频 ---
if ($Video) {
  try { $video = (Resolve-Path -LiteralPath $Video -ErrorAction Stop).Path } catch { Write-Output "ERROR: 视频不存在: $Video"; exit 2 }
}
else {
  $cand = @(Get-ChildItem -LiteralPath $root -Filter '*.mp4' -ErrorAction SilentlyContinue)
  if ($pres) { $cand += @(Get-ChildItem -LiteralPath $pres.FullName -Filter '*.mp4' -ErrorAction SilentlyContinue) }
  if (-not $cand) { Write-Output "ERROR: 未找到 mp4（可用 -Video 指定）"; exit 2 }
  $video = ($cand | Sort-Object Length -Descending | Select-Object -First 1).FullName
}

# --- marks.json（master timeline）---
$marks = $null
$mc = @()
if ($pres) {
  $mc += (Join-Path $pres.FullName 'raw\marks.json')
  $mc += (Join-Path $pres.FullName 'raw-vertical\marks.json')
}
$mc += (Join-Path $root 'raw\marks.json')
$mc += (Join-Path $root 'raw-vertical\marks.json')
foreach ($p in $mc) { if ((-not $marks) -and (Test-Path -LiteralPath $p)) { $marks = $p } }
if (-not $marks) { Write-Output "ERROR: 未找到 marks.json（master timeline）"; exit 2 }

# --- beats.json（口播文本）---
$beatText = @{}
$beats = Join-Path $root 'beats.json'
if (Test-Path -LiteralPath $beats) {
  foreach ($b in @((Get-Content -LiteralPath $beats -Raw -Encoding UTF8 | ConvertFrom-Json))) { $beatText[$b.step_id] = $b.text }
}

# --- ffmpeg 解析（Windows PATH 版本可能是坏 shim → 回退 WSL）---
$useWsl = $false
$saved = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
try { & ffmpeg -version *>$null; if ($LASTEXITCODE -ne 0) { $useWsl = $true } }
catch { $useWsl = $true }
if ($useWsl) {
  try { & wsl -e bash -lc 'which ffmpeg' *>$null; if ($LASTEXITCODE -ne 0) { throw } }
  catch { $ErrorActionPreference = $saved; Write-Output "ERROR: 无可用 ffmpeg（Windows 与 WSL 均不可用）"; exit 2 }
  Write-Output "[INFO] Windows ffmpeg 不可用，改用 WSL ffmpeg"
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

# 视频时长（最后一拍用）
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
[void]$sb.AppendLine("# 抽帧目检清单 · $ep")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("> 由 tools\pipeline\shots-review.ps1 自动生成（勿手改结构）。逐拍核对后勾选。")
[void]$sb.AppendLine("> 兜底机器查不出的语义问题：图表数值与标注是否一致 / 每拍信息量 / 例子来源是否标注 / 钩子回收与衔接 / 留白节奏。")
[void]$sb.AppendLine("> 视频：``$video``")
[void]$sb.AppendLine("> 帧目录：``$out``")
[void]$sb.AppendLine("")
foreach ($r in $rows) {
  [void]$sb.AppendLine("### $($r.Id) · $($r.Sec)s")
  if ($r.Text) { [void]$sb.AppendLine("- 口播：$($r.Text)") }
  [void]$sb.AppendLine("- 帧：``$($r.Img)``")
  [void]$sb.AppendLine("- [ ] 图表数值与标注一致　[ ] 信息量足够　[ ] 例子来源已标注　[ ] 钩子/衔接成立")
  [void]$sb.AppendLine("- 备注：")
  [void]$sb.AppendLine("")
}
$sb.ToString() | Set-Content -LiteralPath $md -Encoding UTF8

Write-Output ""
Write-Output "OK: 清单 -> $md"
Write-Output ("    帧数 = {0}（目录：{1}）" -f $rows.Count, $out)
exit 0
