# Daily heartbeat launcher for Xiaohongshu (2026-10-27)
# Invoked by Trae Schedule as "foreground, outside sandbox + spawned via WMI" (so the process is not reclaimed when the session ends).
# This script: completes PATH / resolves the model / injects CODEBUDDY_CONFIG_DIR / writes CLI output into cache\heartbeat\.
# Note: this file must be saved as UTF-8 with BOM, otherwise PowerShell 5.1 parses it as GBK and the text becomes garbled.
# Do not use Stop: PowerShell 5.1 treats the CLI's ordinary log lines on stderr as errors and terminates the script
$ErrorActionPreference = 'Continue'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
# Optional: the CodeBuddy CLI config directory (when unset the CLI keeps its own default)
if (-not $env:CODEBUDDY_CONFIG_DIR -and (Test-Path (Join-Path $env:USERPROFILE '.codebuddy'))) {
    $env:CODEBUDDY_CONFIG_DIR = (Join-Path $env:USERPROFILE '.codebuddy')
}
# WMI-spawned processes only inherit the system PATH and cannot see the user-level npm global dir, so it must be added explicitly
$env:PATH = "$env:APPDATA\npm;$env:PATH"
Set-Location $Root

$LogDir = Join-Path $Root 'cache\heartbeat'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
$CodeBuddy = if ($env:CODEBUDDY_CLI) { $env:CODEBUDDY_CLI } else { Join-Path $env:APPDATA 'npm\codebuddy.ps1' }

function Write-Log([string]$Text) {
    $Text | Out-File -FilePath $Log -Append -Encoding UTF8
}

"=== heartbeat start $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $Log -Encoding UTF8

try {
    if (-not (Test-Path $CodeBuddy)) { throw "codebuddy.ps1 not found: $CodeBuddy (set CODEBUDDY_CLI to point at your CLI)" }

    # Model is optional: when HEARTBEAT_MODEL is unset the CLI uses its own default model
    $Model = $env:HEARTBEAT_MODEL
    Write-Log ("model={0}" -f ($(if ($Model) { $Model } else { '(cli default)' })))
    $Prompt = if ($env:HEARTBEAT_PROMPT) { $env:HEARTBEAT_PROMPT } else { 'Run the heartbeat check.' }

    # Do not redirect with `*>>`: PowerShell 5.1 wraps the CLI's ordinary stderr logs into NativeCommandError and aborts the script.
    # Instead use Start-Process to write stdout/stderr to separate files, then merge them (no spaces in the JSON so it is not split when joined into arguments).
    $OutFile = "$Log.out"
    $ErrFile = "$Log.err"
    $CliArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $CodeBuddy,
                 '-p', '-y', '--settings', '{"enableAllProjectMcpServers":true}')
    if ($Model) { $CliArgs += @('--model', $Model) }
    $CliArgs += $Prompt
    $Proc = Start-Process -FilePath 'powershell' `
        -ArgumentList $CliArgs `
        -NoNewWindow -PassThru -Wait -RedirectStandardOutput $OutFile -RedirectStandardError $ErrFile
    # Note: under PS5.1 WaitForExit()+Refresh() cannot read ExitCode, so wait with -Wait
    $Code = if ($null -ne $Proc.ExitCode) { $Proc.ExitCode } else { -1 }

    if (Test-Path $OutFile) { Get-Content $OutFile -Encoding UTF8 | Out-File -FilePath $Log -Append -Encoding UTF8 }
    if (Test-Path $ErrFile) { Get-Content $ErrFile -Encoding UTF8 | Out-File -FilePath $Log -Append -Encoding UTF8 }
    Write-Log "=== heartbeat end $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') exit=$Code ==="
    exit $Code
}
catch {
    Write-Log "=== heartbeat abort $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
    Write-Log ($_.Exception.Message + "`n" + $_.ScriptStackTrace)
    exit 1
}
