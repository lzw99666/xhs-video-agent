<#
normalize-bom.ps1 —— 把项目里所有 PowerShell 脚本（.ps1）开头的 UTF-8 BOM 归一为「恰好 1 个」。

背景：编辑工具每次保存会给 .ps1 追加一个 BOM，累积成多 BOM 会让 Windows PowerShell 5.1
      解析失败（报 Unexpected token '...'）；反之完全没有 BOM 会让中文按 ANSI 读成乱码。
      规范：**.ps1 必须恰好 1 个 BOM**。check.ps1 的 C12 断言会扫出不合规的文件。

用法（在仓库根目录下运行）：
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\normalize-bom.ps1           # 修复
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\normalize-bom.ps1 -Check    # 只检查不修（有不合规则退出码 1）
#>
[CmdletBinding()]
param(
  [string]$Path = '',
  [switch]$Check
)

$projRoot = if ($Path) { (Resolve-Path -LiteralPath $Path).Path } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$files = @(Get-ChildItem -LiteralPath $projRoot -Recurse -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|cache|videos|\.venv)\\' })

$bad = 0
foreach ($f in $files) {
  $b = [System.IO.File]::ReadAllBytes($f.FullName)
  $n = 0
  while (($n + 2) -lt $b.Length -and $b[$n] -eq 0xEF -and $b[$n + 1] -eq 0xBB -and $b[$n + 2] -eq 0xBF) { $n += 3 }
  if ($n -eq 3) { continue }
  if ($Check) { Write-Output ("[BAD] {0}  BOM={1}" -f $f.Name, $n); $bad++; continue }
  $t = [System.IO.File]::ReadAllText($f.FullName).TrimStart([char]0xFEFF)
  [System.IO.File]::WriteAllText($f.FullName, $t, (New-Object System.Text.UTF8Encoding $true))
  Write-Output ("[FIX] {0}  BOM {1} -> 1" -f $f.Name, $n)
  $bad++
}
Write-Output ("扫描 {0} 个 .ps1，需处理 {1} 个" -f $files.Count, $bad)
if ($Check -and $bad -gt 0) { exit 1 } else { exit 0 }
