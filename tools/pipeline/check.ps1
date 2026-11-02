<#
check.ps1 —— 五工序契约闸门（改进 C）+ master timeline 覆盖率核对（改进 B·脚本部分）

用途：在每道工序边界机械校验"上道工序是否已定稿/完整"，防止"未定稿就动笔"与"带病交付"。
与 tools\gate\validate.ps1 分工：validate 管【发布合规】，本脚本管【工序契约】。

用法（在仓库根目录下运行）：
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/pipeline/check.ps1 `
      -ProjectDir videos/regular-ep09-reliability -Gate delivery

gate（校验到哪一步）：
  pre-script  写 script 前 —— 只验 facts 是否定稿
  pre-code    写章节代码前 —— 验 facts + script + outline（三要素 / 步数一致）
  pre-render  出片前 —— 再加 数量守恒(C4) + 音频(C6)
  delivery    交付/发布前 —— 全部 + 时间轴一致性(C5，最严)
  media       仅媒体层 —— 只验 数量守恒(C4)+时间轴(C5)+音频(C6)，跳过文本三件套
              （gh-daily 线根目录无 facts/script/outline 时用）
  all         不按工序门，文件存在即验（默认）

开关：
  -SkipFacts    跳过 facts.md 校验（gh-daily 线豁免调研卡时使用）
  -Determinism  额外做帧哈希确定性核对：首跑写基准 raw\shots.sha256，再渲一次复跑即比对

2026-10-19 变更：
  C7（内容可用性）由 FAIL 降级为 WARN —— 内容质量改由 skill 自带质检机制把关
    （SCRIPT-STYLE 四层自检 + CHAPTER-CRAFT 完工自检），机械断言只作提醒。
  C8（人设红线）保持 FAIL，不降级。
  新增 C9 画面元素：章节 tsx 是否引用 components/viz 具象元素（WARN）。
  新增 C10 文案自检存证：script-selfcheck.md 存在且覆盖四层自检
    （pre-code / pre-render / delivery 门为 FAIL）。
2026-10-27 变更：
  新增 C13 创作前三问存证：design-intent.md 存在且非占位（**仅 WARN，不阻断**，
    见 WORKFLOW 8.4「cheat → 创作三段回路」）。

退出码：0 = 全绿（WARN 不阻断）；1 = 有 FAIL；2 = 参数/环境错误
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

# --- 路径解析 ---
try { $root = (Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop).Path }
catch { Write-Output "ERROR: ProjectDir 不存在: $ProjectDir"; exit 2 }
if (-not (Test-Path -LiteralPath $root -PathType Container)) { Write-Output "ERROR: 不是目录: $root"; exit 2 }

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
  # 按 '---' 切块，只统计"含真实口播文本"的块（排除题头块与纯标题/引用/空行块），
  # 避免把题头下的横向分隔线误算成一拍。
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
  foreach ($t in @('TODO', '待补', '待定', '待填', 'placeholder', 'xxxx')) {
    if ($text -match [regex]::Escape($t)) { return $t }
  }
  return $null
}

# --- C13 · 创作前三问存证（2026-10-27 新增，仅 WARN，不阻断） ---
# 内容判断不交给硬编码规则：只提示"design-intent 有没有真的写"，不判断内容好坏（见 WORKFLOW 8.4）。
if ($Gate -in @('all', 'pre-script', 'pre-code', 'pre-render', 'delivery')) {
  $diPath = Join-Path $root 'design-intent.md'
  if (-not (Test-Path -LiteralPath $diPath)) {
    Add-Result 'WARN' 'C13-design-intent' '缺 design-intent.md（创作前三问未落盘，见 WORKFLOW 8.4）'
  }
  else {
    $di = Read-Raw $diPath
    $diLen = if ($di) { $di.Trim().Length } else { 0 }
    $diPh = if ($di) { Test-Placeholder $di } else { $null }
    if ($diLen -lt 120) {
      Add-Result 'WARN' 'C13-design-intent' ("design-intent.md 过短（{0} 字符），三问可能未具体回答" -f $diLen)
    }
    elseif ($diPh) {
      Add-Result 'WARN' 'C13-design-intent' ("design-intent.md 含占位符 '{0}'，判定未完成" -f $diPh)
    }
    else { Add-Result 'PASS' 'C13-design-intent' 'design-intent.md 已落盘（创作前三问）' }
  }
}

# --- C1 · facts 定稿（工序一） ---
if ($needFacts) {
  $f = Read-Raw $facts
  if (-not $f) {
    Add-Result 'FAIL' 'C1-facts-exists' "缺少 facts.md 调研卡：$facts（调研不实不动笔）"
  }
  else {
    $ph = Test-Placeholder $f
    if ($ph) { Add-Result 'FAIL' 'C1-facts-final' "facts.md 含占位符 '$ph'，判定未定稿" }
    else { Add-Result 'PASS' 'C1-facts-final' 'facts.md 无占位符，视为定稿' }
    if ($f -match '(?m)^#{2,3}\s*[一二三四五]、?\s*信源') { Add-Result 'PASS' 'C1-sources' '含「信源清单」段' }
    else { Add-Result 'FAIL' 'C1-sources' 'facts.md 缺「## 一、信源清单」段' }
    if ($f -match '(?m)^#{2,3}\s*[一二三四五]、?\s*关键数据') { Add-Result 'PASS' 'C1-data' '含「关键数据（带出处）」段' }
    else { Add-Result 'FAIL' 'C1-data' 'facts.md 缺「## 二、关键数据（带出处）」段' }
  }
}

# --- C2 · script 定稿（工序二） ---
$beats_script = $null
if ($needScript) {
  $s = Read-Raw $scriptMd
  if (-not $s) { Add-Result 'FAIL' 'C2-script-exists' "缺少 script.md：$scriptMd" }
  else {
    $ph = Test-Placeholder $s
    if ($ph) { Add-Result 'FAIL' 'C2-script-final' "script.md 含占位符 '$ph'，判定未定稿" }
    else { Add-Result 'PASS' 'C2-script-final' 'script.md 无占位符，视为定稿' }
    $beats_script = Count-Beats $scriptMd
    if ($beats_script -ge 2) { Add-Result 'PASS' 'C2-beats' ("script.md 拍数（--- 分隔）= {0}" -f $beats_script) }
    else { Add-Result 'FAIL' 'C2-beats' ("script.md 拍数异常（{0}），应 ≥2" -f $beats_script) }
  }
}

# --- C3 · outline 分镜要素（工序三） ---
if ($needOutline) {
  $o = Read-Raw $outline
  if (-not $o) { Add-Result 'FAIL' 'C3-outline-exists' "缺少 outline.md：$outline" }
  else {
    $lines = Get-Content -LiteralPath $outline -Encoding UTF8
    $chapN = 0; $stepSum = 0; $missing = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^##\s+\S+.*｜\s*(\d+)\s*步') {
        $chapN++; $stepSum += [int]$Matches[1]
        $hdr = $null
        for ($j = $i + 1; $j -lt [Math]::Min($i + 15, $lines.Count); $j++) {
          if ($lines[$j] -match '^\|\s*step\s*\|') { $hdr = $lines[$j]; break }
        }
        if ((-not $hdr) -or ($hdr -notmatch '转场') -or ($hdr -notmatch '视觉焦点') -or ($hdr -notmatch '保护')) {
          $missing += $lines[$i].Trim()
        }
      }
    }
    if ($chapN -eq 0) { Add-Result 'FAIL' 'C3-sections' 'outline.md 未发现「## …｜N 步」章节声明' }
    else { Add-Result 'PASS' 'C3-sections' ("outline.md 章数 {0}，声明步数合计 {1}" -f $chapN, $stepSum) }
    if ($missing.Count -eq 0) { Add-Result 'PASS' 'C3-three-elems' '每章表头含 转场/视觉焦点/保护 三要素' }
    else { Add-Result 'FAIL' 'C3-three-elems' ("以下章节表头缺三要素: " + ($missing -join ' | ')) }
    if ($beats_script -and ($stepSum -ne $beats_script)) {
      Add-Result 'FAIL' 'C3-steps-match' ("outline 步数({0}) ≠ script 拍数({1})" -f $stepSum, $beats_script)
    }
    elseif ($beats_script) {
      Add-Result 'PASS' 'C3-steps-match' ("outline 步数 == script 拍数 == {0}" -f $stepSum)
    }
  }
}

# --- C4 · 数量守恒（工序四/五） ---
if ($needMedia) {
  if (-not $pres) { Add-Result 'FAIL' 'C4-pres' "未找到含 presentation 的网页工程目录" }
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
        @{ n = 'narrations 条目'; v = $n_narr },
        @{ n = 'audio-segments 条目'; v = $n_seg },
        @{ n = 'public/audio mp3 数'; v = $n_mp3 },
        @{ n = 'beats.json 条目'; v = $n_beats })) {
      if (($null -ne $p.v) -and ($p.v -ne $ref)) { $bad += ("{0}={1}" -f $p.n, $p.v) }
    }
    if ($bad.Count -eq 0) { Add-Result 'PASS' 'C4-counts' ("数量守恒：全部 == {0}" -f $ref) }
    else { Add-Result 'FAIL' 'C4-counts' ("数量不守恒（基准 {0}）：{1}" -f $ref, ($bad -join '; ')) }
    if ($null -eq $n_seg) { Add-Result ($(if ($strict) { 'FAIL' } else { 'WARN' })) 'C4-seg' '缺 audio-segments.json' }
    if ($null -eq $n_beats) { Add-Result ($(if ($strict) { 'FAIL' } else { 'WARN' })) 'C4-beats' '缺 beats.json' }
  }
}

# --- C5 · 时间轴一致性 / master timeline 覆盖率（工序四） ---
if ($needMedia -and $pres) {
  $pp = $pres.FullName
  if (Test-Path $beats) {
    $bj = @((Get-Content -LiteralPath $beats -Raw -Encoding UTF8 | ConvertFrom-Json))
    $errs = @()
    foreach ($b in $bj) {
      foreach ($k in @('step_id', 'chapter', 'step', 'start_ms', 'dur_ms', 'text')) {
        if (-not ($b.PSObject.Properties.Name -contains $k)) { $errs += ("{0}.{1} 缺失" -f $b.step_id, $k) }
      }
      if ($b.dur_ms -le 0) { $errs += ("{0}.dur_ms<=0" -f $b.step_id) }
    }
    if ($errs.Count -eq 0) { Add-Result 'PASS' 'C5-beats-schema' 'beats.json 字段完整、dur_ms>0' }
    else { Add-Result 'FAIL' 'C5-beats-schema' ("beats.json 异常: " + ($errs -join ', ')) }

    $marksPath = Join-Path $pp 'raw\marks.json'
    if (Test-Path $marksPath) {
      $mj = Get-Content -LiteralPath $marksPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $markIds = @($mj.marks | ForEach-Object { $_.id })
      $missing = @($bj | ForEach-Object { $_.step_id } | Where-Object { $markIds -notcontains $_ })
      if ($missing.Count -eq 0) { Add-Result 'PASS' 'C5-marks-cover' ("marks.json（master timeline）覆盖全部 {0} 步" -f $bj.Count) }
      else { Add-Result 'FAIL' 'C5-marks-cover' ("marks.json 缺 {0} 步: {1}" -f $missing.Count, ($missing -join ',')) }
    }
    else { Add-Result 'WARN' 'C5-marks-cover' 'raw\marks.json 未留存（出片后清理 raw\ 属正常），无法核对帧覆盖' }

    $shotsDir = Join-Path $pp 'raw\shots'
    if (Test-Path $shotsDir) {
      $n_shot = @(Get-ChildItem -LiteralPath $shotsDir -Filter '*.png').Count
      if ($n_shot -eq $bj.Count) { Add-Result 'PASS' 'C5-shots' ("raw\shots 帧数({0}) == beats 步数" -f $n_shot) }
      else { Add-Result 'FAIL' 'C5-shots' ("raw\shots 帧数({0}) ≠ beats 步数({1})" -f $n_shot, $bj.Count) }
    }
    else { Add-Result 'WARN' 'C5-shots' 'raw\shots 未留存，无法核对帧覆盖' }
  }
}

# --- C6 · 音频存在且非空（工序五） ---
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
    if (($missing.Count -eq 0) -and ($empty.Count -eq 0)) { Add-Result 'PASS' 'C6-audio' ("{0} 段音频全部存在且非空" -f $segs.Count) }
    else {
      if ($missing.Count) { Add-Result 'FAIL' 'C6-audio-missing' ("缺音频文件: " + (($missing | Select-Object -First 5) -join ', ')) }
      if ($empty.Count) { Add-Result 'FAIL' 'C6-audio-empty' ("音频过小(疑似空/静音): " + (($empty | Select-Object -First 5) -join ', ')) }
    }
  }
  else { Add-Result ($(if ($strict) { 'FAIL' } else { 'WARN' })) 'C6-audio' '无 audio-segments.json，跳过音频核对' }
}

# --- C7 · 内容可用性（2026-10-18 新增，治"内容烂"；全机械可查，不做 AI 判断） ---
# 背景：C1~C6 只验工艺（定稿/数量守恒/时间轴/音频），烂稿可全绿通过。
# C7 补的是"观众能不能听懂"这一层：教学设计段 + 结尾落点 + 钩子闭环 + 术语首现解释。
#
# 【2026-10-19 调整】C7 全部由 FAIL 降级为 WARN —— 用户裁定：内容质量**不要用硬编码
# 规则去约束**，改由 skill 自带质检机制把关（SCRIPT-STYLE 四层自检 + CHAPTER-CRAFT
# 完工自检），机械断言只留作提醒。人设红线 C8 仍为 FAIL（红线不降级）。
$c7 = 'WARN'
if ($needFacts) {
  $f = Read-Raw $facts
  if ($f) {
    $sect = $null
    if ($f -match '(?ms)^#{2,3}[^\r\n]*教学设计[^\r\n]*\r?\n(.*?)(?=^#{1,3}\s|\z)') { $sect = $Matches[1] }
    if (-not $sect) {
      Add-Result $c7 'C7-facts-design' 'facts.md 缺「## 四、教学设计」段（facts 不能只是事实台账，必须含讲法设计）'
    }
    else {
      $miss = @()
      foreach ($it in @(
          @{ n = '教学目标';     p = '教学目标' },
          @{ n = '观众前置假设'; p = '前置(假设|知识)' },
          @{ n = '例子上下文';   p = '上下文' },
          @{ n = '体验翻译';     p = '体验' },
          @{ n = '论证链/叙事弧'; p = '论证链|叙事弧' },
          @{ n = '结尾落点';     p = '落点|可执行|建议' })) {
        if ($sect -notmatch $it.p) { $miss += $it.n }
      }
      if ($miss.Count -eq 0) { Add-Result 'PASS' 'C7-facts-design' '教学设计段 6 子项齐全（目标/前置/例子上下文/体验翻译/论证链/落点）' }
      else { Add-Result $c7 'C7-facts-design' ("教学设计段缺子项: " + ($miss -join ', ')) }
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

    # C7a · 结尾落点：末 2 拍须含可执行/结论句（观众看完得知道做什么）
    $tail2 = ($texts | Select-Object -Last 2) -join ' '
    if (($n -ge 2) -and ($tail2 -match '你可以|建议|记住|设成|调成|试试|下次|如果你|往下压|往上放|固定|一句话')) {
      Add-Result 'PASS' 'C7a-ending-action' '结尾含可执行/结论句'
    } else {
      Add-Result $c7 'C7a-ending-action' '结尾 2 拍无可执行建议句（观众看完不知道做什么）'
    }

    # C7b · 钩子闭环：首拍抛出的疑问须在末 3 拍被回收
    $head  = $texts[0]
    $tail3 = ($texts | Select-Object -Last 3) -join ' '
    if ($head -match '为什么|是不是|有没有|总是|老|忽|居然|竟然|同一个|一样|反而|却|一会|一会儿') {
      if ($tail3 -match '所以|这就是|回到|原因|开头|一开始|那句|其实') { Add-Result 'PASS' 'C7b-hook-loop' '钩子有回收句，悬念闭合' }
      else { Add-Result $c7 'C7b-hook-loop' '首拍钩子抛出的事件在结尾未被回收（悬念悬空）' }
    } else {
      Add-Result 'WARN' 'C7b-hook-loop' '首拍未识别到钩子疑问句，跳过闭环检查'
    }

    # C7c · 术语首现须解释（对零前置观众）
    $termMiss = @()
    foreach ($term in @(
        @{ n = 'Temperature'; p = 'Temperature' },
        @{ n = 'Top P';       p = 'Top[ -]?P' },
        @{ n = 'logit';       p = 'logit' },
        @{ n = 'softmax';     p = 'softmax' })) {
      $idx = -1
      for ($i = 0; $i -lt $n; $i++) { if ($texts[$i] -match $term.p) { $idx = $i; break } }
      if ($idx -ge 0) {
        if ($texts[$idx] -notmatch '就是|意思是|可以理解|简单说|说白了|相当于|也就是|指的是') { $termMiss += $term.n }
      }
    }
    if ($termMiss.Count -eq 0) { Add-Result 'PASS' 'C7c-term-explain' '术语首次出现处均有解释句' }
    else { Add-Result $c7 'C7c-term-explain' ("以下术语首现未解释: " + ($termMiss -join ', ') + '（零前置观众会听不懂）') }
  }
}

# --- C8 · 人设红线扫描（2026-10-18 新增，治"编造个人经历"；全机械可查，不做 AI 判断） ---
# 规则：script.md 出现第一人称经历表述（我踩过/我实测/我做过/我试过/我跑通…）时，
#       facts.md 必须含「## 五、实证清单」段，且逐条列出该表述对应的真实记录（日期/文件/来源）。
#       缺段或未覆盖即 FAIL —— 对应 account.md 红线「不得编造个人经历与实测数据」。
if ($needScript) {
  $s8 = Read-Raw $scriptMd
  if ($s8) {
    $claimPat = '我踩过|我踩坑|我实测|我测试过|我试过|我做过|我跑通|我用过|我摸索|我亲身|我亲手|我自己(跑|试|做|测|搭|拧|写)'
    $claimTags = New-Object System.Collections.ArrayList
    foreach ($ln in (Get-Content -LiteralPath $scriptMd -Encoding UTF8)) {
      $t = $ln.Trim()
      if (($t -eq '') -or ($t.StartsWith('#')) -or ($t.StartsWith('>'))) { continue }
      foreach ($m in [regex]::Matches($t, $claimPat)) {
        $tag = if ($m.Value -match '^我自己') { '我自己' } else { $m.Value }
        if ($claimTags -notcontains $tag) { [void]$claimTags.Add($tag) }
      }
    }
    if ($claimTags.Count -eq 0) {
      Add-Result 'PASS' 'C8-persona-claims' 'script 无第一人称经历表述，无编造风险'
    }
    else {
      $f8 = Read-Raw $facts
      if (-not $f8) {
        Add-Result 'FAIL' 'C8-persona-claims' ("script 含第一人称经历表述（{0}），但缺 facts.md 无法核验实证" -f ($claimTags -join '/'))
      }
      else {
        $sec8 = $null
        if ($f8 -match '(?ms)^#{2,3}[^\r\n]*实证清单[^\r\n]*\r?\n(.*?)(?=^#{1,3}\s|\z)') { $sec8 = $Matches[1] }
        if (-not $sec8) {
          Add-Result 'FAIL' 'C8-persona-claims' ("script 含第一人称经历表述（{0}），但 facts.md 缺「## 五、实证清单」段 → 疑编造个人经历" -f ($claimTags -join '/'))
        }
        else {
          $unbacked = @($claimTags | Where-Object { $sec8 -notmatch [regex]::Escape($_) })
          if ($unbacked.Count -eq 0) { Add-Result 'PASS' 'C8-persona-claims' ("实证清单已覆盖全部第一人称表述：{0}" -f ($claimTags -join '/')) }
          else { Add-Result 'FAIL' 'C8-persona-claims' ("以下第一人称经历表述无实证记录：{0}（红线：不得编造个人经历）" -f ($unbacked -join '/')) }
        }
      }
    }
  }
}

# --- C9 · 画面元素（2026-10-19 新增，治"画面空洞 / 内容只占屏 1/3"；WARN 不阻断） ---
# 规则：每个章节 tsx 至少引用 1 个 components/viz 具象元素（讲到什么挂什么）。
# 只做"有没有用"的机械判断；"每步 ≥1 个 + 与口播相关 + 中部主视觉 ≥55%"这类
# 语义判断留给 CHAPTER-CRAFT.md 完工自检（人工/AI 审核）。
if ($needOutline -and $pres) {
  $chapDir = Join-Path $pres.FullName 'src\chapters'
  if (Test-Path -LiteralPath $chapDir) {
    $tsx = @(Get-ChildItem -LiteralPath $chapDir -Recurse -Filter '*.tsx' -ErrorAction SilentlyContinue)
    $noViz = @()
    foreach ($t in $tsx) {
      $raw = Get-Content -LiteralPath $t.FullName -Raw -Encoding UTF8
      if ($raw -notmatch 'components/viz') { $noViz += $t.Name }
    }
    if ($tsx.Count -eq 0) { Add-Result 'WARN' 'C9-viz' 'src\chapters 下无章节 tsx，无法核对画面元素' }
    elseif ($noViz.Count -eq 0) { Add-Result 'PASS' 'C9-viz' ("{0} 个章节全部引用 components/viz 具象元素" -f $tsx.Count) }
    else { Add-Result 'WARN' 'C9-viz' ("以下章节未引用 components/viz 具象元素（画面可能空洞）: " + ($noViz -join ', ')) }
  }
}

# --- C10 · 文案自检存证（2026-10-19 新增，治"文案不行"） ---
# 规则：Phase 1 必须按 SCRIPT-STYLE.md 的四层自检（形式层 / 风骨层 / 念出来 / 结构层）
#       走完 → 修稿 → 落盘 script-selfcheck.md 存证。pre-code 起强制。
if ($Gate -in @('pre-code', 'pre-render', 'delivery')) {
  $sc = Join-Path $root 'script-selfcheck.md'
  if (Test-Path -LiteralPath $sc) {
    $scRaw = Read-Raw $sc
    if (($scRaw -match '形式') -and ($scRaw -match '风骨') -and ($scRaw -match '念出来') -and ($scRaw -match '结构')) {
      # 2026-10-31 收紧：四层自检只是「走过形式」，开场三要素与盲读复述必须留下逐项判定，
      # 否则无法区分「真的读过」与「只写了四个小标题」（ep11 连续四版都栽在开场，见 SCRIPT-STYLE 第 7 条）。
      $hasElements = ($scRaw -match '三要素') -and ($scRaw -match '(?m)^.*PASS|MISSING')
      $hasBlind = ($scRaw -match '盲读')
      if ($hasElements -and $hasBlind) {
        Add-Result 'PASS' 'C10-script-selfcheck' 'script-selfcheck.md 覆盖四层自检 + 开场三要素逐项判定 + 盲读复述'
      }
      else {
        $miss = @()
        if (-not $hasElements) { $miss += '开场三要素逐项判定（谁/什么事/为什么值得看，各标 PASS 或 MISSING）' }
        if (-not $hasBlind) { $miss += '盲读复述记录（含第 5 项开场三要素）' }
        Add-Result 'FAIL' 'C10-script-selfcheck' ("script-selfcheck.md 缺：" + ($miss -join '；'))
      }
    }
    else { Add-Result 'FAIL' 'C10-script-selfcheck' 'script-selfcheck.md 未覆盖四层自检（形式/风骨/念出来/结构），视同未走完' }
  }
  else { Add-Result 'FAIL' 'C10-script-selfcheck' '缺 script-selfcheck.md：Phase 1 未按 SCRIPT-STYLE 四层自检存证（禁止进入 Phase 2）' }
}

# --- C14 · 时长估算（2026-10-31 新增；WARN） ---
# 背景：脚本 591 字按 3.3 字/秒估 179s，实际 TTS 出片 153.3s（13 拍 × 1.5s 停留）。
# 实测语速接近 4 字/秒，字数口径必须换成实测值，否则每篇都会系统性偏短/偏长。
# 判据：est = 汉字数 / 4.0 + 拍数 × 1.5；目标带 120–180s，超出只 WARN 不阻断。
if ($Gate -in @('pre-code', 'pre-render', 'delivery')) {
  if (Test-Path -LiteralPath $scriptMd) {
    $body = (Get-Content -LiteralPath $scriptMd -Encoding UTF8 | Where-Object {
        $t = $_.Trim(); ($t -ne '') -and (-not $t.StartsWith('#')) -and (-not $t.StartsWith('>'))
      }) -join "`n"
    $cjk = ([regex]::Matches($body, '[\u4e00-\u9fff]')).Count
    $beats = ([regex]::Matches($body, '(?m)^---$')).Count + 1
    if ($cjk -gt 0) {
      $est = [math]::Round($cjk / 4.0 + $beats * 1.5, 0)
      if (($est -lt 120) -or ($est -gt 180)) {
        Add-Result 'WARN' 'C14-duration' ("估算 $est s（${cjk}字 / ${beats}拍）不在 120–180s 目标带；口径 = 字数/4 + 拍×1.5")
      }
      else { Add-Result 'PASS' 'C14-duration' "估算 $est s（${cjk}字 / ${beats}拍）在目标带内" }
    }
  }
}

# --- C15 · 账本 JSON 完整性（2026-10-31 新增；FAIL） ---
# 背景：手工改 backlog/.cheat-state 两次留下尾逗号，导致 CLI 启动即崩、白跑一轮。
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
        Add-Result 'PASS' 'C15-json' "$jf 解析通过"
      }
      catch { Add-Result 'FAIL' 'C15-json' "$jf 不是合法 JSON：$($_.Exception.Message)" }
    }
  }
}

# --- C11 · 口播稿结构（2026-10-19 新增，治"结构散架"；pre-code / pre-render / delivery 生效） ---
# 背景：措辞全过、结构散架的稿子照样让人听不懂（ep08 就栽在这，见 SCRIPT-STYLE 第 5 节）。
# 做三层机械断言：
#   C11-seq  分类树自洽 —— 同一层级不得混用量词（路/种/类/档），序号不得跳号。
#   C11-list 编号必列项 —— 报了「N 项」必须把 N 项列出来，禁止只报编号。
#   C11-term 术语首现即解释 —— 术语首现的那一拍、其后 40 字内须含其关键词（表见 terminology.txt）。
# 【收紧说明 2026-10-19】C11-list 初版对合格稿大量误伤（「个」量词、「两件事」、
#   「」内示例全被命中），已收紧为：仅认「件/条/种/步/坑」量词、N≥3、跳过引号内示例，
#   方做到 ep08 命中、ep07/06/05/04 不误伤（详见回归报告）。
if ($Gate -in @('pre-code', 'pre-render', 'delivery')) {
  $sRaw = Read-Raw $scriptMd
  if ($sRaw) {
    # 正文行（去标题/引用/分隔线），压成无空白串，便于按"字"开窗
    $bl = New-Object System.Collections.ArrayList
    foreach ($ln in (Get-Content -LiteralPath $scriptMd -Encoding UTF8)) {
      $t = $ln.Trim()
      if (($t -eq '') -or $t.StartsWith('#') -or $t.StartsWith('>') -or ($t -match '^[-*_]{3,}$')) { continue }
      [void]$bl.Add($t)
    }
    $body = ($bl -join '') -replace '\s+', ''

    # 逐拍（--- 分隔）正文，供 C11-term 做「首现那一拍」定位
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

    $numMap = @{ '一' = 1; '二' = 2; '两' = 2; '三' = 3; '四' = 4; '五' = 5; '六' = 6; '七' = 7; '八' = 8; '九' = 9; '十' = 10 }
    function Convert-CnNum([string]$w) {
      if ($w -match '^\d+$') { return [int]$w }
      if ($numMap.ContainsKey($w)) { return [int]$numMap[$w] }
      return -1
    }

    # ---- C11-seq 序号一致性 ----
    $seqHits = @([regex]::Matches($body, '第\s*([一二三四五六七八九十两\d]+)\s*(路|种|类|档)'))
    if ($seqHits.Count -eq 0) {
      Add-Result 'PASS' 'C11-seq' '未发现「第X路/种/类/档」量词编号，跳过'
    }
    else {
      $seqErrs = @()
      $hasLu  = @($seqHits | Where-Object { $_.Groups[2].Value -eq '路' }).Count -gt 0
      $hasAlt = @($seqHits | Where-Object { @('种', '类') -contains $_.Groups[2].Value }).Count -gt 0
      if ($hasLu -and $hasAlt) {
        $seqErrs += ('量词混用（同一层级并列「路」与「种/类」）: ' + (($seqHits | ForEach-Object { $_.Value }) -join ' / '))
      }
      foreach ($g in ($seqHits | Group-Object { $_.Groups[2].Value })) {
        $nums = @($g.Group | ForEach-Object { Convert-CnNum $_.Groups[1].Value } | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
        if ($nums.Count -ge 2) {
          $missing = @()
          for ($v = $nums[0]; $v -le $nums[-1]; $v++) { if ($nums -notcontains $v) { $missing += $v } }
          if ($missing.Count -gt 0) { $seqErrs += ('「第X' + $g.Name + '」序号跳号，缺: ' + ($missing -join ',')) }
        }
      }
      if ($seqErrs.Count -eq 0) { Add-Result 'PASS' 'C11-seq' ('量词/序号自洽（{0} 处编号）' -f $seqHits.Count) }
      else { Add-Result 'FAIL' 'C11-seq' ('分类树序号不自洽: ' + ($seqErrs -join ' | ')) }
    }

    # ---- C11-list 编号必列项（收紧版） ----
    $bodyNoQ = [regex]::Replace($body, '[「“『][^」”』]*[」”』]', '')
    $listHits = @([regex]::Matches($bodyNoQ, '(?<![一二三四五六七八九十两\d第])([三四五六七八九十]|\d+)\s*(件|条|种|步|坑)') | Where-Object { (Convert-CnNum $_.Groups[1].Value) -ge 3 })
    $listErrs = @()
    foreach ($m in $listHits) {
      $N = Convert-CnNum $m.Groups[1].Value
      $st = $m.Index + $m.Length
      $win = if ($st -lt $bodyNoQ.Length) { $bodyNoQ.Substring($st, [Math]::Min(60, $bodyNoQ.Length - $st)) } else { '' }
      $immediate = ($win.Length -gt 0) -and ($win.StartsWith('：') -or $win.StartsWith(':'))
      $sepCount = ([regex]::Matches($win, '、')).Count
      if ((-not $immediate) -and ($sepCount -lt ($N - 1))) {
        $listErrs += ('报了 {0} 项却没列出内容（「{1}」处）' -f $N, $m.Value)
      }
    }
    if ($listHits.Count -eq 0) { Add-Result 'PASS' 'C11-list' '未发现需列项的编号表述，跳过' }
    elseif ($listErrs.Count -eq 0) { Add-Result 'PASS' 'C11-list' ('{0} 处编号均有列项' -f $listHits.Count) }
    else { Add-Result 'FAIL' 'C11-list' ('编号未列项: ' + ($listErrs -join ' | ')) }

    # ---- C11-term 术语首现即解释 ----
    $termPath = Join-Path $PSScriptRoot 'terminology.txt'
    if (-not (Test-Path -LiteralPath $termPath)) {
      $defTerms = "harness`t循环的代码|跑循环|循环`r`nDOM`t骨架|原始骨架|网页结构`r`n无障碍树`t读屏|读屏软件`r`n提示注入`t指令|指挥`r`nAPI`t接口|指挥"
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
        if (-not $hit) { $termErrs += ('{0} 首现后 40 字内无解释（关键词: {1}）' -f $term, ($kws -join '/')) }
        break
      }
    }
    if ($termChecked -eq 0) { Add-Result 'PASS' 'C11-term' '稿中未见术语表所列术语，跳过' }
    elseif ($termErrs.Count -eq 0) { Add-Result 'PASS' 'C11-term' ('{0} 个出现的术语首现即解释' -f $termChecked) }
    else { Add-Result 'FAIL' 'C11-term' ('术语首现未解释: ' + ($termErrs -join ' | ')) }
  }
}

# --- C12 · PowerShell 脚本 BOM 归一（2026-10-19 新增） ---
# 背景：编辑工具每次保存会给 .ps1 追加一个 BOM，累积成多 BOM 会让 Windows PowerShell 5.1
#   解析失败（报 Unexpected token）；反之无 BOM 会让中文被按 ANSI 读成乱码。规范：**恰好 1 个 BOM**。
#   修复：powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\normalize-bom.ps1
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
if ($badBom.Count -eq 0) { Add-Result 'PASS' 'C12-bom' ("{0} 个 .ps1 均为单 BOM" -f $psFiles.Count) }
else { Add-Result 'FAIL' 'C12-bom' ('BOM 未归一（应恰好 1 个；跑 tools\pipeline\normalize-bom.ps1 修复）: ' + ($badBom -join ', ')) }

# --- D1 · 确定性核对（-Determinism，改进 B） ---
if ($Determinism -and $pres) {
  $pp = $pres.FullName
  $shotsDir = Join-Path $pp 'raw\shots'
  $manifest = Join-Path $pp 'raw\shots.sha256'
  if (-not (Test-Path $shotsDir)) { Add-Result 'WARN' 'D1' 'raw\shots 不存在，无法做确定性核对（先出片再跑 -Determinism）' }
  else {
    $cur = Get-ChildItem -LiteralPath $shotsDir -Filter '*.png' | Sort-Object Name | ForEach-Object {
      "{0}  {1}" -f $_.Name, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    if (Test-Path $manifest) {
      $old = Get-Content -LiteralPath $manifest -Encoding UTF8
      $diff = Compare-Object $old $cur
      if (-not $diff) { Add-Result 'PASS' 'D1' '两次渲染帧哈希一致 → 确定性通过（无抽卡）' }
      else { Add-Result 'FAIL' 'D1' ("两次渲染帧哈希不一致 → 存在抽卡（{0} 处差异）" -f @($diff).Count) }
    }
    else {
      $cur | Set-Content -LiteralPath $manifest -Encoding UTF8
      Add-Result 'WARN' 'D1' "首次运行：已写基准哈希 -> raw\shots.sha256（再渲一次复跑本项即比对）"
    }
  }
}

# --- 汇总 ---
$nPass = @($results | Where-Object { $_.Level -eq 'PASS' }).Count
$nWarn = @($results | Where-Object { $_.Level -eq 'WARN' }).Count
$nFail = @($results | Where-Object { $_.Level -eq 'FAIL' }).Count
$code = if ($nFail -gt 0) { 1 } else { 0 }
Write-Output ("RESULT: project={0} gate={1} pass={2} warn={3} fail={4} EXIT={5}" -f (Split-Path $root -Leaf), $Gate, $nPass, $nWarn, $nFail, $code)
exit $code
