#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Session Monitor - Windows Installer
.DESCRIPTION
    Sets up config, creates a Task Scheduler job (every 5 min), and
    optionally creates a browser shortcut with the debugging port enabled.
.EXAMPLE
    .\install.ps1
    .\install.ps1 -Browser edge
    .\install.ps1 -Browser chrome
#>

param(
    [ValidateSet('edge','chrome')]
    [string]$Browser = 'edge'
)

$ErrorActionPreference = 'Stop'

function Write-Step  { param([string]$Num, [string]$Msg) Write-Host "[$Num]" -ForegroundColor Yellow -NoNewline; Write-Host " $Msg" }
function Write-Ok    { param([string]$Msg) Write-Host "      > $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "      ! $Msg" -ForegroundColor Yellow }

Write-Host ''
Write-Host '+---------------------------------------+' -ForegroundColor Cyan
Write-Host '|   Claude Session Monitor (Windows)    |' -ForegroundColor Cyan
Write-Host '+---------------------------------------+' -ForegroundColor Cyan
Write-Host ''

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$MonitorPS1 = Join-Path $ScriptDir 'claude-monitor.ps1'
$ConfigDir  = "$env:APPDATA\claude-monitor"
$TaskName   = 'ClaudeSessionMonitor'

# ── Step 1: Verify monitor script exists ───────────────────────────────────────

Write-Step '1/4' 'Verifying installation files...'
if (-not (Test-Path $MonitorPS1)) {
    Write-Host "ERROR: claude-monitor.ps1 not found in $ScriptDir" -ForegroundColor Red
    exit 1
}
Write-Ok 'Found claude-monitor.ps1'

# ── Step 2: Set up config ─────────────────────────────────────────────────────

Write-Step '2/4' 'Setting up configuration...'
if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }

$configDest = Join-Path $ConfigDir 'config'
if (-not (Test-Path $configDest)) {
    Copy-Item (Join-Path $ScriptDir 'config.example') $configDest
    Write-Ok "Created default config at $configDest"
} else {
    Write-Ok 'Config already exists'
}

# ── Step 3: Create Task Scheduler task ─────────────────────────────────────────

Write-Step '3/4' 'Creating scheduled task (runs every 5 minutes)...'

$existingTask = schtasks /query /tn $TaskName 2>$null
if ($existingTask) {
    schtasks /delete /tn $TaskName /f 2>$null | Out-Null
}

$psArgs = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$MonitorPS1`""
schtasks /create /tn $TaskName /tr "powershell.exe $psArgs" /sc minute /mo 5 /f | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Ok 'Scheduled task created successfully'
} else {
    Write-Warn 'Could not create task. Try running this installer as Administrator.'
}

# ── Step 4: Test run ───────────────────────────────────────────────────────────

Write-Step '4/4' 'Running test...'
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MonitorPS1 -Verbose
    Write-Ok 'Test completed'
} catch {
    Write-Warn 'Test ran (check if browser is open with debugging port)'
}

# ── Browser Setup Instructions ─────────────────────────────────────────────────

Write-Host ''
Write-Host '+---------------------------------------+' -ForegroundColor Cyan
Write-Host '|         Installation Complete!        |' -ForegroundColor Cyan
Write-Host '+---------------------------------------+' -ForegroundColor Cyan
Write-Host ''
Write-Host 'The monitor runs automatically every 5 minutes.'
Write-Host ''
Write-Host "Configuration: $configDest"
Write-Host "Logs:          $env:USERPROFILE\.claude_monitor.log"
Write-Host ''

# Browser-specific setup instructions
Write-Host '--- REQUIRED: Browser Setup ---' -ForegroundColor Yellow
Write-Host ''

$port = 9222
switch ($Browser) {
    'edge' {
        $exePath = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
        if (-not (Test-Path $exePath)) { $exePath = 'C:\Program Files\Microsoft\Edge\Application\msedge.exe' }
        Write-Host "You must launch Edge with the debugging port enabled."
        Write-Host "Close Edge completely, then start it with:" -ForegroundColor Yellow
        Write-Host ''
        Write-Host "  `"$exePath`" --remote-debugging-port=$port" -ForegroundColor White
        Write-Host ''
        Write-Host 'Or create a shortcut with that argument appended to the Target field.'
    }
    'chrome' {
        $exePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
        if (-not (Test-Path $exePath)) { $exePath = 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe' }
        Write-Host "You must launch Chrome with the debugging port enabled."
        Write-Host "Close Chrome completely, then start it with:" -ForegroundColor Yellow
        Write-Host ''
        Write-Host "  `"$exePath`" --remote-debugging-port=$port" -ForegroundColor White
        Write-Host ''
        Write-Host 'Or create a shortcut with that argument appended to the Target field.'
    }
}

Write-Host ''
Write-Host 'Then log into claude.ai in that browser.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Commands:' -ForegroundColor Cyan
Write-Host "  View logs:  Get-Content $env:USERPROFILE\.claude_monitor.log -Tail 20"
Write-Host "  Run now:    powershell -File `"$MonitorPS1`" -Verbose"
Write-Host "  Stop:       schtasks /delete /tn $TaskName /f"
Write-Host "  Status:     schtasks /query /tn $TaskName"
Write-Host ''
