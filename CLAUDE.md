# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Session Monitor is a macOS-only automation tool that monitors Claude Pro/Max usage limits. It scrapes usage percentages from `claude.ai/settings/usage` via Chrome's AppleScript JavaScript execution and sends native Mac notifications every 10% (10%, 20%, ... 100%) for both **Current Session** and **Weekly limits**.

## Architecture

The project has zero external dependencies—it uses only macOS built-ins:

- **claude-monitor.sh** — Bash script with embedded AppleScript that:
  1. Finds any Chrome tab with `claude.ai`, navigates to the usage page if needed
  2. Executes JavaScript via AppleScript to read DOM text nodes for "X% used" patterns
  3. Parses both Current Session and Weekly percentages
  4. Compares against 10% thresholds and fires `osascript` notifications
  5. Persists state separately for session and weekly to prevent duplicate alerts

- **com.syam.claude-session-watch.plist** — launchd agent that runs the script every 5 minutes

State and log files:
- `~/.claude_monitor_session` — tracks last fired session threshold
- `~/.claude_monitor_weekly` — tracks last fired weekly threshold
- `~/.claude_monitor.log` — stdout logs
- `~/.claude_monitor_err.log` — stderr logs

## Development Commands

```bash
# Run manually for testing
bash claude-monitor.sh

# Monitor logs
tail -f ~/.claude_monitor.log

# Reset state (to re-trigger notifications)
rm -f ~/.claude_monitor_session ~/.claude_monitor_weekly

# Manage launchd service
launchctl list | grep claude                                      # check status
launchctl unload ~/Library/LaunchAgents/com.syam.claude-session-watch.plist  # stop
launchctl load ~/Library/LaunchAgents/com.syam.claude-session-watch.plist    # start

# Test notifications
osascript -e 'display notification "test" with title "Test"'
```

## Key Implementation Details

- **Dual tracking**: Scrapes two "X% used" values from page — first is Current Session, second is Weekly limits
- **Threshold logic** (`check_threshold` function): Iterates 10-100 in steps of 10; fires once per threshold. State resets when usage drops below last notified threshold.
- **Graceful exit**: Script exits cleanly with log warning if Chrome isn't open or Claude tab not found.
