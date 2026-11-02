# 抓取创作者中心数据 -> data/metrics/latest.json
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File tools\metrics\pull.ps1
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (-not (Test-Path '.\session.json')) {
        Write-Host '[需登录] 缺少 session.json，请先运行: node tools\metrics\login.js' -ForegroundColor Yellow
        exit 2
    }
    node pull.js
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
