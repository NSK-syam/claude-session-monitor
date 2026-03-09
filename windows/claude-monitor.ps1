#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Session Monitor for Windows
.DESCRIPTION
    Monitors Claude Pro/Max usage by scraping claude.ai/settings/usage via
    Chrome DevTools Protocol. Sends Windows notifications at configurable
    thresholds for both Current Session and Weekly limits.

    Prerequisites: Chrome or Edge must be running with --remote-debugging-port=9222
#>

param([switch]$Verbose)

$ErrorActionPreference = 'Continue'

# ── Config ─────────────────────────────────────────────────────────────────────

$script:ConfigDir        = "$env:APPDATA\claude-monitor"
$script:ConfigFile       = "$script:ConfigDir\config"
$script:SessionStateFile = "$env:USERPROFILE\.claude_monitor_session"
$script:WeeklyStateFile  = "$env:USERPROFILE\.claude_monitor_weekly"
$script:HistoryFile      = "$env:USERPROFILE\.claude_monitor_history"
$script:LogFile          = "$env:USERPROFILE\.claude_monitor.log"

$script:Thresholds = @(10,20,30,40,50,60,70,80,90,100)
$script:DebugPort  = 9222

if (Test-Path $script:ConfigFile) {
    Get-Content $script:ConfigFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $key, $val = $line -split '=', 2
            switch ($key.Trim()) {
                'THRESHOLDS' { $script:Thresholds = ($val -split ',') | ForEach-Object { [int]$_.Trim() } }
                'DEBUG_PORT' {
                    $p = 0
                    if ([int]::TryParse($val.Trim(), [ref]$p) -and $p -ge 1 -and $p -le 65535) {
                        $script:DebugPort = $p
                    }
                }
            }
        }
    }
}

# ── Logging ────────────────────────────────────────────────────────────────────

function Write-Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')] $Message"
    Add-Content -Path $script:LogFile -Value $entry -Encoding UTF8
    if ($Verbose) { Write-Host $entry }
}

# ── Notifications ──────────────────────────────────────────────────────────────

function Send-Notification {
    param([string]$Title, [string]$Message)

    $sent = $false

    # Windows 10+ toast notification via WinRT (works in PowerShell 5.1)
    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

        $escapedTitle = [System.Security.SecurityElement]::Escape($Title)
        $escapedMsg   = [System.Security.SecurityElement]::Escape($Message)

        $toastXml = @"
<toast duration="long">
  <visual>
    <binding template="ToastGeneric">
      <text>$escapedTitle</text>
      <text>$escapedMsg</text>
    </binding>
  </visual>
  <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@
        $doc = [Windows.Data.Xml.Dom.XmlDocument]::New()
        $doc.LoadXml($toastXml)
        $toast = [Windows.UI.Notifications.ToastNotification]::New($doc)
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
        $sent = $true
    } catch {}

    # Fallback: system tray balloon (auto-promoted to toast on Win10+)
    if (-not $sent) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $icon = New-Object System.Windows.Forms.NotifyIcon
            $icon.Icon             = [System.Drawing.SystemIcons]::Warning
            $icon.BalloonTipIcon   = [System.Windows.Forms.ToolTipIcon]::Warning
            $icon.BalloonTipTitle  = $Title
            $icon.BalloonTipText   = $Message
            $icon.Visible = $true
            $icon.ShowBalloonTip(10000)
            Start-Sleep -Milliseconds 500
            $icon.Dispose()
        } catch {}
    }

    Write-Log "ALERT: $Title - $Message"
}

# ── Chrome DevTools Protocol ───────────────────────────────────────────────────

$script:UsageJS = @'
(function(){
  var text = document.body.innerText || '';
  var matches = text.match(/\d+% used/ig) || [];
  var s = '', w = '';
  var sm = text.match(/Current session[\s\S]*?(\d+% used)/i);
  if (sm) s = sm[1];
  var wm = text.match(/Weekly limits[\s\S]*?(\d+% used)/i);
  if (!wm) wm = text.match(/All models[\s\S]*?(\d+% used)/i);
  if (wm) w = wm[1];
  if (!s && !w && matches.length > 0) {
    s = matches[0] || ''; w = matches[1] || '';
  } else if (!s && matches.length > 0 && matches[0] !== w) {
    s = matches[0];
  } else if (!w && matches.length > 1) {
    w = matches[1];
  }
  return (s || '') + '|' + (w || '');
})()
'@

function Send-CdpCommand {
    param(
        [string]$WsUrl,
        [string]$Method,
        [hashtable]$Params = @{},
        [switch]$WaitForResponse
    )

    $ws     = New-Object System.Net.WebSockets.ClientWebSocket
    $cts    = New-Object System.Threading.CancellationTokenSource 15000
    $stream = $null

    try {
        $ws.ConnectAsync([Uri]$WsUrl, $cts.Token).GetAwaiter().GetResult() | Out-Null

        $json  = @{ id = 1; method = $Method; params = $Params } | ConvertTo-Json -Depth 10 -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $seg   = New-Object System.ArraySegment[byte] (,$bytes)
        $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).GetAwaiter().GetResult() | Out-Null

        if (-not $WaitForResponse) { return $null }

        $buffer = New-Object byte[] 65536
        for ($i = 0; $i -lt 30; $i++) {
            $stream = New-Object System.IO.MemoryStream
            do {
                $rseg = New-Object System.ArraySegment[byte] (,$buffer)
                $recv = $ws.ReceiveAsync($rseg, $cts.Token).GetAwaiter().GetResult()
                $stream.Write($buffer, 0, $recv.Count)
            } while (-not $recv.EndOfMessage)

            $text = [System.Text.Encoding]::UTF8.GetString($stream.ToArray())
            $stream.Dispose(); $stream = $null

            $parsed = $text | ConvertFrom-Json
            if ($parsed -and $parsed.id -eq 1) { return $parsed }
        }
        return $null
    }
    catch { return $null }
    finally {
        if ($stream) { $stream.Dispose() }
        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            try { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, '', [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null } catch {}
        }
        $ws.Dispose()
        $cts.Dispose()
    }
}

function Get-UsageFromBrowser {
    try {
        $tabs = Invoke-RestMethod -Uri "http://localhost:$($script:DebugPort)/json" -TimeoutSec 5
    } catch {
        return $null
    }

    $claudeTab = $tabs | Where-Object { $_.url -like '*claude.ai*' } | Select-Object -First 1
    if (-not $claudeTab -or -not $claudeTab.webSocketDebuggerUrl) { return $null }

    $wsUrl = $claudeTab.webSocketDebuggerUrl

    if ($claudeTab.url -notlike '*settings/usage*') {
        Send-CdpCommand -WsUrl $wsUrl -Method 'Page.navigate' -Params @{ url = 'https://claude.ai/settings/usage' }
        Start-Sleep -Seconds 4
    }

    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $response = Send-CdpCommand -WsUrl $wsUrl -Method 'Runtime.evaluate' -Params @{
            expression    = $script:UsageJS
            returnByValue = $true
        } -WaitForResponse

        if ($response -and $response.result -and $response.result.result -and $response.result.result.value) {
            $val = $response.result.result.value
            if ($val -match '\d+% used') { return $val }
        }
        Start-Sleep -Seconds 2
    }
    return $null
}

# ── Parse ──────────────────────────────────────────────────────────────────────

function Get-Percent {
    param([string]$Text)
    if ($Text -match '^(\d+)') { return [int]$Matches[1] }
    return 0
}

# ── Usage Prediction ───────────────────────────────────────────────────────────

function Update-History {
    param([int]$Percent)

    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    Add-Content -Path $script:HistoryFile -Value "$timestamp,$Percent" -Encoding UTF8

    if (Test-Path $script:HistoryFile) {
        $lines = @(Get-Content $script:HistoryFile -Encoding UTF8)
        if ($lines.Count -gt 20) {
            $lines[-20..-1] | Set-Content $script:HistoryFile -Encoding UTF8
        }
    }
}

function Get-TimeToFull {
    param([int]$CurrentPercent)

    if (-not (Test-Path $script:HistoryFile)) { return '' }
    $lines = @(Get-Content $script:HistoryFile -Encoding UTF8 | Where-Object { $_ -match '^\d+,\d+$' })
    if ($lines.Count -lt 2) { return '' }

    $oldest = $lines[0] -split ','
    $newest = $lines[-1] -split ','

    $timeDiff    = [int]$newest[0] - [int]$oldest[0]
    $percentDiff = [int]$newest[1] - [int]$oldest[1]

    if ($percentDiff -le 0 -or $timeDiff -le 0) { return '' }

    $remaining      = 100 - $CurrentPercent
    $secondsToFull  = [int](($remaining * $timeDiff) / $percentDiff)

    if ($secondsToFull -lt 60)   { return '<1 min' }
    if ($secondsToFull -lt 3600) { return "$([int]($secondsToFull / 60)) min" }

    $hours = [int]($secondsToFull / 3600)
    $mins  = [int](($secondsToFull % 3600) / 60)
    return "${hours}h ${mins}m"
}

# ── Threshold Check ────────────────────────────────────────────────────────────

function Test-Threshold {
    param(
        [string]$Name,
        [int]$Percent,
        [string]$StateFile,
        [string]$Prediction
    )

    $lastNotified = 0
    if (Test-Path $StateFile) {
        $raw = (Get-Content $StateFile -Encoding UTF8).Trim()
        if ($raw -match '^\d+$') { $lastNotified = [int]$raw }
    }

    if ($Percent -lt $lastNotified) {
        Set-Content $StateFile -Value '0' -Encoding UTF8
        $lastNotified = 0
        if ($Name -eq 'Session') { Remove-Item $script:HistoryFile -ErrorAction SilentlyContinue }
    }

    foreach ($threshold in ($script:Thresholds | Sort-Object)) {
        if ($Percent -ge $threshold -and $lastNotified -lt $threshold) {
            $msg = "${Percent}% used - ${threshold}% threshold"
            if ($Prediction -and $Name -eq 'Session') {
                $msg += " (~$Prediction to limit)"
            }
            Send-Notification "Claude $Name Warning" $msg
            Set-Content $StateFile -Value $threshold -Encoding UTF8
            Write-Log "$Name`: Notified at $threshold% (actual: $Percent%)"
            break
        }
    }
}

# ── Main ───────────────────────────────────────────────────────────────────────

$usageText = Get-UsageFromBrowser

if (-not $usageText) {
    Write-Log 'WARNING: Could not read Claude page - browser must be open with --remote-debugging-port and logged into claude.ai'
    exit 0
}

$parts          = $usageText -split '\|', 2
$sessionText    = $parts[0]
$weeklyText     = if ($parts.Count -gt 1) { $parts[1] } else { '' }

$sessionPercent = Get-Percent $sessionText
$weeklyPercent  = Get-Percent $weeklyText

Update-History $sessionPercent
$prediction = Get-TimeToFull $sessionPercent

$logMsg = "Current Session: $sessionPercent% | Weekly: $weeklyPercent%"
if ($prediction) { $logMsg += " | ETA: ~$prediction" }
Write-Log $logMsg

if ($sessionText) { Test-Threshold 'Session' $sessionPercent $script:SessionStateFile $prediction }
if ($weeklyText)  { Test-Threshold 'Weekly'  $weeklyPercent  $script:WeeklyStateFile  '' }
