# Claude Session Monitor

Automatic Mac notifications when your Claude usage hits configurable thresholds — tracks both **Current Session** and **Weekly limits**.

**Features:**
- One-command installer
- Custom notification thresholds (10%, 25%, 50%, etc.)
- Multi-browser support (Chrome, Arc, Safari)
- Usage prediction ("~2h to limit")
- Menu bar widget (via SwiftBar)

## Requirements

- **macOS**
- **Chrome, Arc, or Safari** — must be open and logged into `claude.ai`
- **Claude Pro or Max** subscription

## Quick Install

```bash
git clone https://github.com/NSK-syam/claude-session-monitor.git
cd claude-session-monitor
./install.sh
```

That's it! The monitor runs automatically every 5 minutes.

## What You Get

```
[2026-03-06 19:00] Current Session: 31% | Weekly: 28% | ETA: ~2h 15m
```

Notifications fire at each threshold (default: every 10%). Includes time prediction showing when you'll hit the limit.

## Configuration

Edit `~/.config/claude-monitor/config`:

```bash
# Custom thresholds (comma-separated)
THRESHOLDS=25,50,75,90,100

# Browser order (tries each until one works)
BROWSERS=chrome,arc,safari
```

## Menu Bar Widget

Shows live usage in your menu bar with color coding (green/orange/red).

1. Install SwiftBar:
   ```bash
   brew install --cask swiftbar
   ```

2. Run SwiftBar once and set your plugins folder

3. Install the plugin:
   ```bash
   ./install.sh --menubar
   ```

## Browser Setup

### Chrome / Arc
Menu bar: **View → Developer → Allow JavaScript from Apple Events**

### Safari
**Safari → Settings → Advanced → Show Develop menu**
Then: **Develop → Allow JavaScript from Apple Events**

## Commands

```bash
# View live logs
tail -f ~/.claude_monitor.log

# Check status
launchctl list | grep claude

# Stop monitor
launchctl unload ~/Library/LaunchAgents/com.claude.session-monitor.plist

# Start monitor
launchctl load ~/Library/LaunchAgents/com.claude.session-monitor.plist

# Run manually
bash ~/claude-session-monitor/claude-monitor.sh
```

## Make Notifications Stay Longer

By default, Mac notifications disappear quickly. To make them stay until dismissed:

**System Settings → Notifications → Terminal → Change "Banners" to "Alerts"**

## How It Works

1. launchd runs the script every 5 minutes
2. Script checks Chrome → Arc → Safari (in order) for Claude tab
3. Reads "X% used" for both Current Session and Weekly limits
4. Tracks usage history to predict time to 100%
5. Fires Mac notification when any threshold is crossed
6. Menu bar plugin reads the log and displays current status

## Files

| File | Purpose |
|------|---------|
| `claude-monitor.sh` | Core monitoring script |
| `install.sh` | One-command installer |
| `claude-usage.5m.sh` | SwiftBar menu bar plugin |
| `config.example` | Example configuration |

## Privacy & Security

- No API keys or passwords stored
- Runs entirely locally — no data sent anywhere
- Only reads browser tabs — never modifies anything
- Browser JavaScript access is scoped to the browser only

## Troubleshooting

**"Could not read Claude page"**
- Browser must be open with `claude.ai` logged in
- Enable JavaScript from Apple Events (see Browser Setup above)

**No notifications**
- System Settings → Notifications → Terminal → Allow
- Test: `osascript -e 'display notification "test" with title "Test"'`

**Menu bar not updating**
- Click the menu bar icon → Refresh
- Or run: `bash ~/claude-session-monitor/claude-monitor.sh`

## License

MIT
