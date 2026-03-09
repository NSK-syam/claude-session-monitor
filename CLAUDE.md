# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Session Monitor monitors Claude Pro/Max usage limits. It scrapes usage percentages from `claude.ai/settings/usage` via browser automation and sends native desktop notifications at configurable thresholds for both **Current Session** and **Weekly limits**. Supports **macOS** and **Windows**.

## Architecture

Zero external dependencies—uses only OS built-ins.

### macOS (`claude-monitor.sh`)

Uses AppleScript to interact with browsers and `osascript` for notifications:

- **claude-monitor.sh** — Core monitoring script:
 - Multi-browser support: Chrome, Arc, Safari (tries in config order)
 - Configurable thresholds via `~/.config/claude-monitor/config`
 - Usage prediction (tracks history, estimates time to 100%)
 - Separate state tracking for session vs weekly

- **install.sh** — One-command installer:
 - Auto-generates launchd plist with correct paths
 - Creates config directory and default config
 - Loads the launchd agent

- **claude-usage.5m.sh** — SwiftBar menu bar plugin

### Windows (`windows/`)

Uses Chrome DevTools Protocol (CDP) over WebSocket to interact with Chrome/Edge, and WinRT toast notifications:

- **windows/claude-monitor.ps1** — Core monitoring script:
 - Connects to browser via CDP (port 9222)
 - Finds claude.ai tab, navigates to usage page
 - Executes JavaScript via `Runtime.evaluate`
 - Windows toast notifications (WinRT) with BalloonTip fallback
 - Same threshold/prediction logic as macOS

- **windows/install.ps1** — One-command installer:
 - Creates config in `%APPDATA%\claude-monitor`
 - Sets up Task Scheduler job (every 5 min via `schtasks`)
 - Browser-specific setup instructions

- **windows/uninstall.ps1** — Clean removal of task and state files

## Files and State

### macOS

| File | Purpose |
|------|---------|
| `~/.config/claude-monitor/config` | User configuration |
| `~/.claude_monitor_session` | Last session threshold notified |
| `~/.claude_monitor_weekly` | Last weekly threshold notified |
| `~/.claude_monitor_history` | Usage history for prediction |
| `~/.claude_monitor.log` | Stdout logs |

### Windows

| File | Purpose |
|------|---------|
| `%APPDATA%\claude-monitor\config` | User configuration |
| `%USERPROFILE%\.claude_monitor_session` | Last session threshold notified |
| `%USERPROFILE%\.claude_monitor_weekly` | Last weekly threshold notified |
| `%USERPROFILE%\.claude_monitor_history` | Usage history for prediction |
| `%USERPROFILE%\.claude_monitor.log` | Stdout logs |

## Development Commands

### macOS

```bash
# Install/reinstall
./install.sh

# Install with menu bar
./install.sh --menubar

# Run manually
bash claude-monitor.sh

# Monitor logs
tail -f ~/.claude_monitor.log

# Reset state (re-trigger notifications)
rm -f ~/.claude_monitor_session ~/.claude_monitor_weekly ~/.claude_monitor_history

# Manage service
launchctl list | grep claude
launchctl unload ~/Library/LaunchAgents/com.claude.session-monitor.plist
launchctl load ~/Library/LaunchAgents/com.claude.session-monitor.plist
```

### Windows (PowerShell)

```powershell
# Install
.\windows\install.ps1

# Run manually
powershell -File .\windows\claude-monitor.ps1 -Verbose

# Monitor logs
Get-Content $env:USERPROFILE\.claude_monitor.log -Tail 20 -Wait

# Reset state
Remove-Item $env:USERPROFILE\.claude_monitor_session, $env:USERPROFILE\.claude_monitor_weekly, $env:USERPROFILE\.claude_monitor_history -ErrorAction SilentlyContinue

# Manage service
schtasks /query /tn ClaudeSessionMonitor
schtasks /delete /tn ClaudeSessionMonitor /f
.\windows\install.ps1  # to recreate

# Uninstall
.\windows\uninstall.ps1 -CleanAll
```

## Key Implementation Details

### Shared Logic (both platforms)
- **Prediction**: Linear extrapolation from history file (last 20 data points)
- **Threshold logic**: Iterates configured thresholds, fires once per threshold
- **Session reset detection**: Clears history when usage drops (new session started)

### macOS-Specific
- **Browser fallback**: `get_usage_percents()` tries each browser in `$BROWSERS` order via AppleScript
- **Notifications**: `osascript` → macOS Notification Center

### Windows-Specific
- **CDP connection**: Connects to `localhost:$DEBUG_PORT/json`, finds claude.ai tab via WebSocket
- **JS execution**: `Runtime.evaluate` over CDP WebSocket, with retry loop for slow page loads
- **Notifications**: WinRT toast API (PS 5.1) with BalloonTip fallback (PS 7+)
