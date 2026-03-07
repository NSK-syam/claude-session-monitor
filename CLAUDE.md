# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Session Monitor is a macOS-only automation tool that monitors Claude Pro/Max usage limits. It scrapes usage percentages from `claude.ai/settings/usage` via browser AppleScript and sends native Mac notifications at configurable thresholds for both **Current Session** and **Weekly limits**.

## Architecture

Zero external dependencies—uses only macOS built-ins:

- **claude-monitor.sh** — Core monitoring script:
  - Multi-browser support: Chrome, Arc, Safari (tries in config order)
  - Configurable thresholds via `~/.config/claude-monitor/config`
  - Usage prediction (tracks history, estimates time to 100%)
  - Separate state tracking for session vs weekly

- **install.sh** — One-command installer:
  - Auto-generates launchd plist with correct paths
  - Creates config directory and default config
  - Loads the launchd agent

- **claude-usage.5m.sh** — SwiftBar menu bar plugin:
  - Shows current usage % with color coding
  - Reads from log file (no direct browser access)

- **config.example** — Example configuration file

## Files and State

| File | Purpose |
|------|---------|
| `~/.config/claude-monitor/config` | User configuration |
| `~/.claude_monitor_session` | Last session threshold notified |
| `~/.claude_monitor_weekly` | Last weekly threshold notified |
| `~/.claude_monitor_history` | Usage history for prediction |
| `~/.claude_monitor.log` | Stdout logs |

## Development Commands

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

## Key Implementation Details

- **Browser fallback**: `get_usage_percents()` tries each browser in `$BROWSERS` order
- **Prediction**: `predict_time_to_full()` uses linear extrapolation from history file
- **Threshold logic**: `check_threshold()` iterates configured thresholds, fires once per threshold
- **Session reset detection**: Clears history when usage drops (new session started)
