# Claude Session Monitor

Automatic desktop notifications when your Claude usage hits configurable thresholds — tracks both **Current Session** and **Weekly limits**. Works on **macOS** and **Windows**.

**Features:**
- One-command installer
- Custom notification thresholds (10%, 25%, 50%, etc.)
- Multi-browser support (Chrome, Arc, Safari on Mac; Chrome, Edge on Windows)
- Usage prediction ("~2h to limit")
- Menu bar widget (via SwiftBar — macOS only)

## Requirements

- **Claude Pro or Max** subscription
- **macOS** or **Windows 10/11**
- A supported browser open and logged into `claude.ai`

## Quick Install — macOS

```bash
git clone https://github.com/NSK-syam/claude-session-monitor.git
cd claude-session-monitor
./install.sh
```

## Quick Install — Windows

```powershell
git clone https://github.com/NSK-syam/claude-session-monitor.git
cd claude-session-monitor\windows
.\install.ps1
```

That's it! The monitor runs automatically every 5 minutes.

## What You Get

```
[2026-03-06 19:00] Current Session: 31% | Weekly: 28% | ETA: ~2h 15m
```

Notifications fire at each threshold (default: every 10%). Includes time prediction showing when you'll hit the limit.

## Configuration

### macOS

Edit `~/.config/claude-monitor/config`:

```bash
# Custom thresholds (comma-separated)
THRESHOLDS=25,50,75,90,100

# Browser order (tries each until one works)
BROWSERS=chrome,arc,safari
```

### Windows

Edit `%APPDATA%\claude-monitor\config`:

```
THRESHOLDS=25,50,75,90,100

# Chrome DevTools Protocol port
DEBUG_PORT=9222
```

## Menu Bar Widget (macOS only)

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

### macOS — Chrome / Arc
Menu bar: **View → Developer → Allow JavaScript from Apple Events**

### macOS — Safari
**Safari → Settings → Advanced → Show Develop menu**
Then: **Develop → Allow JavaScript from Apple Events**

### Windows — Chrome or Edge

The Windows version uses Chrome DevTools Protocol, which requires launching your browser with a special flag. **Close your browser completely first**, then relaunch it:

**Edge:**
```
"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --remote-debugging-port=9222
```

**Chrome:**
```
"C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222
```

**Tip:** Edit your browser's desktop shortcut and append `--remote-debugging-port=9222` to the Target field so it starts this way automatically.

## Commands

### macOS

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

### Windows (PowerShell)

```powershell
# View live logs
Get-Content $env:USERPROFILE\.claude_monitor.log -Tail 20 -Wait

# Check status
schtasks /query /tn ClaudeSessionMonitor

# Stop monitor
schtasks /delete /tn ClaudeSessionMonitor /f

# Run manually
powershell -File .\windows\claude-monitor.ps1 -Verbose

# Uninstall
.\windows\uninstall.ps1        # keeps config
.\windows\uninstall.ps1 -CleanAll  # removes everything
```

## Make Notifications Stay Longer

### macOS
**System Settings → Notifications → Terminal → Change "Banners" to "Alerts"**

### Windows
**Settings → System → Notifications → PowerShell → Set priority to "Top"**

## How It Works

### macOS
1. launchd runs the script every 5 minutes
2. Script checks Chrome → Arc → Safari (in order) for Claude tab via AppleScript
3. Reads "X% used" for both Current Session and Weekly limits
4. Tracks usage history to predict time to 100%
5. Fires Mac notification when any threshold is crossed
6. Menu bar plugin reads the log and displays current status

### Windows
1. Task Scheduler runs the PowerShell script every 5 minutes
2. Script connects to Chrome/Edge via Chrome DevTools Protocol (port 9222)
3. Finds a `claude.ai` tab and navigates to the usage page
4. Executes JavaScript to extract usage percentages
5. Tracks usage history to predict time to 100%
6. Fires Windows toast notification when any threshold is crossed

## Files

| File | Purpose |
|------|---------|
| `claude-monitor.sh` | Core monitoring script (macOS) |
| `install.sh` | One-command installer (macOS) |
| `claude-usage.5m.sh` | SwiftBar menu bar plugin (macOS) |
| `config.example` | Example configuration (macOS) |
| `windows/claude-monitor.ps1` | Core monitoring script (Windows) |
| `windows/install.ps1` | One-command installer (Windows) |
| `windows/uninstall.ps1` | Uninstaller (Windows) |
| `windows/config.example` | Example configuration (Windows) |

## Privacy & Security

- No API keys or passwords stored
- Runs entirely locally — no data sent anywhere
- Only reads browser tabs — never modifies anything
- Browser JavaScript access is scoped to the browser only

## Troubleshooting

**"Could not read Claude page" (macOS)**
- Browser must be open with `claude.ai` logged in
- Enable JavaScript from Apple Events (see Browser Setup above)

**"Could not read Claude page" (Windows)**
- Browser must be running with `--remote-debugging-port=9222`
- Close the browser completely and relaunch with the flag
- Make sure you're logged into `claude.ai`
- Test connection: open `http://localhost:9222/json` in another browser

**No notifications (macOS)**
- System Settings → Notifications → Terminal → Allow
- Test: `osascript -e 'display notification "test" with title "Test"'`

**No notifications (Windows)**
- Settings → System → Notifications → ensure notifications are on
- Ensure PowerShell is allowed to send notifications

**Menu bar not updating (macOS)**
- Click the menu bar icon → Refresh
- Or run: `bash ~/claude-session-monitor/claude-monitor.sh`

## License

MIT
