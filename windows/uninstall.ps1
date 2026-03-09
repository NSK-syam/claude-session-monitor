#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstalls Claude Session Monitor from Windows.
.DESCRIPTION
    Removes the scheduled task and optionally cleans up config and state files.
.EXAMPLE
    .\uninstall.ps1
    .\uninstall.ps1 -CleanAll
#>

param([switch]$CleanAll)

$ErrorActionPreference = 'Continue'
$TaskName = 'ClaudeSessionMonitor'

Write-Host 'Uninstalling Claude Session Monitor...' -ForegroundColor Yellow
Write-Host ''

# Remove scheduled task
$existing = schtasks /query /tn $TaskName 2>$null
if ($existing) {
    schtasks /delete /tn $TaskName /f | Out-Null
    Write-Host '  Removed scheduled task' -ForegroundColor Green
} else {
    Write-Host '  Scheduled task not found (already removed)' -ForegroundColor Gray
}

if ($CleanAll) {
    $filesToRemove = @(
        "$env:USERPROFILE\.claude_monitor_session",
        "$env:USERPROFILE\.claude_monitor_weekly",
        "$env:USERPROFILE\.claude_monitor_history",
        "$env:USERPROFILE\.claude_monitor.log"
    )
    foreach ($f in $filesToRemove) {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Host "  Removed $f" -ForegroundColor Green }
    }

    $configDir = "$env:APPDATA\claude-monitor"
    if (Test-Path $configDir) {
        Remove-Item $configDir -Recurse -Force
        Write-Host "  Removed $configDir" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
if (-not $CleanAll) {
    Write-Host 'Run with -CleanAll to also remove config and state files.' -ForegroundColor Gray
}
