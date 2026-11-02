# Pull creator-center data -> data/metrics/latest.json
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools\metrics\pull.ps1
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (-not (Test-Path '.\session.json')) {
        Write-Host '[LOGIN REQUIRED] session.json is missing, run first: node tools\metrics\login.js' -ForegroundColor Yellow
        exit 2
    }
    node pull.js
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
