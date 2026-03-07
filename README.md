# Claude Session Monitor

Automatic Mac notifications when your Claude usage hits every 10% — tracks both **Current Session** and **Weekly limits**.

Reads the real usage percentage directly from `claude.ai/settings/usage` in Chrome and fires native Mac notifications at 10%, 20%, 30%... up to 100%.

## Requirements

- **macOS**
- **Google Chrome** — must be open and logged into `claude.ai`
- **Claude Pro or Max** subscription

## Quick Setup

### 1. Clone the repo

```bash
git clone https://github.com/NSK-syam/claude-session-monitor.git
cd claude-session-monitor
```

### 2. Make script executable

```bash
chmod +x claude-monitor.sh
```

### 3. Enable AppleScript in Chrome

1. Open **Google Chrome**
2. Menu bar: **View → Developer → Allow JavaScript from Apple Events**
3. Click to enable (checkmark appears)

### 4. Update paths in the plist

Find your home path:

```bash
echo $HOME
```

Edit `com.syam.claude-session-watch.plist` and replace `/Users/syam` with your path:

```xml
<string>/Users/YOUR_USERNAME/claude-session-monitor/claude-monitor.sh</string>
<string>/Users/YOUR_USERNAME/.claude_monitor.log</string>
<string>/Users/YOUR_USERNAME/.claude_monitor_err.log</string>
```

### 5. Install and start

```bash
cp com.syam.claude-session-watch.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.syam.claude-session-watch.plist
```

Done! It runs automatically every 5 minutes in the background.

## Test It

```bash
bash claude-monitor.sh && tail -5 ~/.claude_monitor.log
```

You should see:

```
[2026-03-06 19:00] Current Session: 31% | Weekly: 28%
```

## What You Get

| Usage | Notification |
|-------|-------------|
| 10% | ⚠️ Claude Session — 10% threshold reached |
| 20% | ⚠️ Claude Session — 20% threshold reached |
| ... | ... |
| 100% | ⚠️ Claude Session — 100% threshold reached |

Same for Weekly limits. Each threshold fires **once** per session/week.

## Make Notifications Stay Longer

By default, Mac notifications disappear in 2 seconds. To make them stay until you dismiss:

**System Settings → Notifications → Terminal → Change "Banners" to "Alerts"**

## Manage the Service

```bash
# Check status
launchctl list | grep claude

# Stop
launchctl unload ~/Library/LaunchAgents/com.syam.claude-session-watch.plist

# Start
launchctl load ~/Library/LaunchAgents/com.syam.claude-session-watch.plist

# View logs
tail -f ~/.claude_monitor.log
```

## Troubleshooting

**"Could not read Claude page"**
- Chrome must be open with `claude.ai` logged in
- Enable: View → Developer → Allow JavaScript from Apple Events

**No notifications**
- System Settings → Notifications → Terminal → Allow notifications
- Test: `osascript -e 'display notification "test" with title "Test"'`

## How It Works

1. launchd runs the script every 5 minutes
2. Script uses AppleScript to read Chrome's Claude tab
3. Parses "X% used" for both Current Session and Weekly
4. Fires Mac notification when any 10% threshold is crossed
5. Tracks state in `~/.claude_monitor_session` and `~/.claude_monitor_weekly`

No credentials stored. Runs entirely locally. Only reads your browser — never modifies anything.

## License

MIT
