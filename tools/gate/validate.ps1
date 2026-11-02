# validate.ps1 — 发布前机械校验闸门（WORKFLOW.md 9.2）
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate\validate.ps1 `
#   -Title "标题" -TagsCount 6 -VideoPath "videos\x.mp4" -CoverPath "cover.png" `
#   -PredictionPath "predictions\x.md" [-NoteType video|image-text]
# 全部通过 exit 0；任一不过打印 [GATE-FAIL] 原因并 exit 1。CLI 发布前强制跑，非零即禁发。
# 检查项：1 标题 / 2 tags / 3 成片存在 / 4 封面 1080x1440（可选，不传即跳过）/ 5 预测哈希锁 / 6 当日篇数 / 7 间隔 2h / 8 halt
#         9 音频硬校验（仅视频笔记）——真响度 loudnorm I + 真峰值 dBTP（非 volumedetect 均值）
# NoteType=image-text（图文笔记）时豁免第 3、9 项，其余全照跑。
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

# 1. 标题 ≤20 字
if ($Title.Length -gt 20) { $fails += "标题 $($Title.Length) 字，超 20 上限" }

# 2. tags 3~6 个
if ($TagsCount -lt 3 -or $TagsCount -gt 6) { $fails += "tags 数量 $TagsCount，须 3~6" }

# 3. 成片存在（图文笔记豁免）
if ($NoteType -eq 'video') {
    if (-not $VideoPath) { $fails += '视频笔记必须提供 -VideoPath' }
    elseif (-not (Test-Path (Join-Path $root $VideoPath))) { $fails += "成片不存在: $VideoPath" }
}

# 4. 封面存在且 1080x1440（**可选**：2026-10-27 用户决定本号不设封面，首帧即封面）
if ($CoverPath) {
    $coverFull = Join-Path $root $CoverPath
    if (-not (Test-Path $coverFull)) {
        $fails += "封面不存在: $CoverPath"
    } else {
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile($coverFull)
        if ($img.Width -ne 1080 -or $img.Height -ne 1440) { $fails += "封面尺寸 $($img.Width)x$($img.Height)，须 1080x1440" }
        $img.Dispose()
    }
} else {
    Write-Host '[GATE-WARN] 未提供封面（本号不设封面，首帧即封面；须确保首帧已承担标题功能）'
}

# 5. 预测档案存在 + 哈希锁匹配
$predFull = Join-Path $root $PredictionPath
$statePath = Join-Path $root '.cheat-state.json'
$state = Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not (Test-Path $predFull)) {
    $fails += "预测档案不存在: $PredictionPath（盲预测是发布前硬节点）"
} else {
    $predKey = $PredictionPath -replace '\\', '/'
    $locked = $state.prediction_hashes.$predKey
    if (-not $locked) { $locked = $state.prediction_hashes.$PredictionPath }
    if (-not $locked) {
        $fails += "预测档案未登记哈希锁（predict 落盘时应写入 prediction_hashes）"
    } else {
        $lines = Get-Content $predFull -Encoding UTF8
        $startIdx = ($lines | Select-String -Pattern '^## 预测' | Select-Object -First 1).LineNumber
        if (-not $startIdx) { $fails += '预测档案缺「## 预测」段' }
        else {
            $rest = $lines[$startIdx..($lines.Count-1)]
            $endRel = ($rest | Select-String -Pattern '^## ' | Select-Object -First 1).LineNumber
            if ($endRel) { $sec = $lines[($startIdx-1)..($startIdx+$endRel-3)] } else { $sec = $lines[($startIdx-1)..($lines.Count-1)] }
            $bytes = [Text.Encoding]::UTF8.GetBytes(($sec -join "`n"))
            $hash = ( ($sha = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)) | ForEach-Object { $_.ToString('x2') }) -join ''
            if ($hash -ne $locked) { $fails += "预测段哈希不匹配——immutable 被破坏，禁发并交回 Trae" }
        }
    }
}

# 6. 频控：单日发布 ≤2 篇（读 log.md 当日条目）
$today = Get-Date -Format 'yyyy-MM-dd'
$logLines = Get-Content (Join-Path $root 'log.md') -Encoding UTF8
$todayCount = ($logLines | Select-String -Pattern "^## $today · 第" | Measure-Object).Count
if ($todayCount -ge 2) { $fails += "今日已发 $todayCount 篇，达单日上限 2" }

# 7. 频控：距上篇 ≥2h（读 state last_published_at）
if ($state.last_published_at) {
    $last = [DateTime]::Parse($state.last_published_at)
    $hours = ((Get-Date) - $last).TotalHours
    if ($hours -lt 2) { $fails += "距上篇发布仅 $([Math]::Round($hours,1))h，不足 2h 间隔" }
}

# 8. 熔断开关
$backlog = Get-Content (Join-Path $root 'backlog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($backlog.halt) { $fails += 'backlog.halt=true，全局停摆禁发' }

# 9. 音频硬校验（视频笔记）：真响度 loudnorm I（LUFS）+ 真峰值（dBTP）—— 口径见 WORKFLOW.md 9.2
#    不用 volumedetect 的 mean_volume：它把静音一起算进均值，含停顿的口播会被误判越界
if ($NoteType -eq 'video' -and $VideoPath) {
    $vFull = Join-Path $root $VideoPath
    # ffmpeg 解析：优先 $env:FFMPEG，其次本机 WinGet 包里的真实 exe（PATH 上的 ffmpeg.exe 是坏 shim，跑不起来）
    $ff = $env:FFMPEG
    if (-not $ff -or -not (Test-Path $ff)) {
        $hit = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\ffmpeg.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        $ff = if ($hit) { $hit.FullName } else { 'ffmpeg' }
    }
    if (Test-Path $vFull) {
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $out = (& $ff -hide_banner -nostats -i $vFull -af loudnorm=print_format=json -f null - 2>&1 | Out-String)
        $ErrorActionPreference = $prev
        # 直接抽 loudnorm JSON 里的两个字段（不做整体 JSON 解析：ffmpeg 输出里还有别的 { } 会干扰正则）
        $mi = [regex]::Match($out, '"input_i"\s*:\s*"(-?[\d.]+)"')
        $mp = [regex]::Match($out, '"input_tp"\s*:\s*"(-?[\d.]+)"')
        if ($mi.Success -and $mp.Success) {
            $I  = [double]$mi.Groups[1].Value
            $tp = [double]$mp.Groups[1].Value
            $audioNote = "I=$I LUFS/TP=$tp dBTP"
            if ($tp -gt -1.0) { $fails += ("真峰值 {0} dBTP，须 ≤ -1.0（削波风险）" -f $tp) }
            if ($I -lt -30 -or $I -gt -14) { $fails += ("响度 {0} LUFS 越界，须 -30..-14" -f $I) }
            elseif ($I -lt -20) { Write-Host ("[GATE-WARN] 响度偏轻 {0} LUFS，建议 loudnorm 到约 -16 LUFS" -f $I) }
        } else {
            $fails += '音频硬校验无法执行：ffmpeg 不可用或 loudnorm 未输出（发布前必须能核验音频）'
        }
    }
}

if ($fails.Count -gt 0) {
    foreach ($f in $fails) { Write-Host "[GATE-FAIL] $f" }
    exit 1
}
Write-Host "[GATE-PASS] 校验全绿（NoteType=$NoteType）：标题$($Title.Length)字 / tags $TagsCount / 成片 / $(if ($CoverPath) { '封面1080x1440' } else { '无封面(首帧即封面)' }) / 预测哈希 / 当日${todayCount}篇 / 间隔${hours}h / 无halt$(if ($audioNote) { ' / 音频 ' + $audioNote })"
exit 0
