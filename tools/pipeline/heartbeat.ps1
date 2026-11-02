# 小红书每日心跳启动器（2026-10-27）
# 由 Trae Schedule 以「前台沙箱外 + WMI 派生」方式调用（避免进程随会话结束被回收）。
# 本脚本负责：补全 PATH / 解析模型 / 注入 CODEBUDDY_CONFIG_DIR / 把 CLI 输出写入 cache\heartbeat\。
# 注意：本文件必须以 UTF-8 BOM 保存，否则 PowerShell 5.1 会按 GBK 解析中文导致乱码。
# 不能用 Stop：PowerShell 5.1 会把 CLI 写到 stderr 的普通日志当成错误记录并终止脚本
$ErrorActionPreference = 'Continue'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
# 可选：CodeBuddy CLI 的配置目录（未设置时沿用 CLI 自己的默认值）
if (-not $env:CODEBUDDY_CONFIG_DIR -and (Test-Path (Join-Path $env:USERPROFILE '.codebuddy'))) {
    $env:CODEBUDDY_CONFIG_DIR = (Join-Path $env:USERPROFILE '.codebuddy')
}
# WMI 派生的进程只继承系统 PATH，拿不到用户级 npm 全局目录，必须显式补全
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
    if (-not (Test-Path $CodeBuddy)) { throw "找不到 codebuddy.ps1：$CodeBuddy（可设置 CODEBUDDY_CLI 指向你的 CLI）" }

    # 模型可选：不设 HEARTBEAT_MODEL 时用 CLI 自己的默认模型
    $Model = $env:HEARTBEAT_MODEL
    Write-Log ("model={0}" -f ($(if ($Model) { $Model } else { '(cli default)' })))
    $Prompt = if ($env:HEARTBEAT_PROMPT) { $env:HEARTBEAT_PROMPT } else { '执行心跳' }

    # 不用 `*>>` 重定向：PowerShell 5.1 会把 CLI 写到 stderr 的普通日志包成 NativeCommandError 并中断脚本。
    # 改用 Start-Process 把 stdout/stderr 分别落盘，再合并（JSON 里不留空格，避免被拼参数时拆开）。
    $OutFile = "$Log.out"
    $ErrFile = "$Log.err"
    $CliArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $CodeBuddy,
                 '-p', '-y', '--settings', '{"enableAllProjectMcpServers":true}')
    if ($Model) { $CliArgs += @('--model', $Model) }
    $CliArgs += $Prompt
    $Proc = Start-Process -FilePath 'powershell' `
        -ArgumentList $CliArgs `
        -NoNewWindow -PassThru -Wait -RedirectStandardOutput $OutFile -RedirectStandardError $ErrFile
    # 注意：PS5.1 下 WaitForExit()+Refresh() 读不到 ExitCode，必须用 -Wait 等待
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
