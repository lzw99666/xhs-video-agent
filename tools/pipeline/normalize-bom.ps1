<#
normalize-bom.ps1 —— normalize the UTF-8 BOM at the start of every PowerShell script (.ps1) in the project to "exactly 1".

Background: the editor appends one BOM to .ps1 on every save, and stacked BOMs make Windows PowerShell 5.1
      fail to parse (Unexpected token '...'); conversely no BOM at all makes text be read as ANSI garbage.
      Rule: **.ps1 must have exactly 1 BOM**. The C12 assertion in check.ps1 flags non-compliant files.

Usage (run from the repo root):
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\normalize-bom.ps1           # fix
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\normalize-bom.ps1 -Check    # check only, no fix (exit 1 if non-compliant)
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
Write-Output ("Scanned {0} .ps1 files, {1} need fixing" -f $files.Count, $bad)
if ($Check -and $bad -gt 0) { exit 1 } else { exit 0 }
