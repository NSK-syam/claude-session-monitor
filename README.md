# Claude Session Monitor 🤖⏱️

> **Automatic Mac notifications before your Claude session hits its usage limit — no manual input, ever.**

Reads the real "Resets in X hr Y min" timer directly from `claude.ai/settings/usage` in Chrome and fires native Mac notifications at 60, 30, 15, and 5 minutes before your session is used up.

---

## The Problem

Claude (Pro/Max) enforces a rolling usage limit per session. When you hit 100%, you're blocked from continuing until it resets. The countdown timer is only visible inside the Claude settings page — there's no email, push notification, or API to warn you.

This tool solves that by automating the check every 5 minutes and alerting you before you're cut off mid-work.

---

## How It Works

```
Every 5 minutes (via macOS launchd)
        │
        ▼
claude-monitor.sh runs
        │
        ▼
AppleScript reads "Resets in X hr Y min"
from your logged-in Chrome tab at claude.ai
        │
        ▼
Checks time against thresholds: 60 / 30 / 15 / 5 min
        │
        ▼
Fires Mac notification if threshold crossed
(each threshold fires only once per session)
        │
        ▼
After session resets → thresholds reset → watching again
```

---

## Files

| File | Purpose |
|------|---------|
| `claude-monitor.sh` | Core script — scrapes Claude, compares timer, fires alerts |
| `com.syam.claude-session-watch.plist` | macOS launchd config — runs the script every 5 min automatically |

---

## Requirements

- **macOS** (uses `osascript` for AppleScript + notifications)
- **Google Chrome** — must be open and logged into `claude.ai`
- **Claude Pro or Max** subscription (the usage page must exist)

---

## Setup (One-Time)

### Step 1 — Clone or copy the files

```bash
git clone https://github.com/NSK-syam/ml.git
cd ml/claude-session-monitor
```

### Step 2 — Make the script executable

```bash
chmod +x claude-monitor.sh
```

### Step 3 — Enable AppleScript JavaScript access in Chrome

This is required for the script to read the Claude page.

1. Open **Google Chrome**
2. In the menu bar: **View → Developer → Allow JavaScript from Apple Events**
3. Click it to enable (a checkmark will appear)

> ⚠️ You only need to do this once. Chrome remembers the setting.

### Step 4 — Update the plist path to match your username

Open `com.syam.claude-session-watch.plist` and replace every instance of `/Users/syam` with your actual home directory path:

```bash
# Find your home path
echo $HOME
```

Then edit the plist:

```xml
<string>/Users/YOUR_USERNAME/path/to/claude-monitor.sh</string>
```

Also update the log file paths:

```xml
<string>/Users/YOUR_USERNAME/.claude_monitor.log</string>
<string>/Users/YOUR_USERNAME/.claude_monitor_err.log</string>
```

### Step 5 — Install the launchd agent

Copy the plist to your LaunchAgents folder and load it:

```bash
cp com.syam.claude-session-watch.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.syam.claude-session-watch.plist
```

✅ Done. It will now run automatically every 5 minutes, including after reboots.

---

## Verify It's Working

Run the script manually once to confirm:

```bash
bash claude-monitor.sh
```

Then check the log:

```bash
tail -f ~/.claude_monitor.log
```

If working, you'll see something like:

```
[2026-02-20 22:25] Session: 155 min remaining ("Resets in 2 hr 35 min")
```

If you see a warning about Chrome, make sure:
- Chrome is open
- You're logged into `claude.ai` in at least one tab
- "Allow JavaScript from Apple Events" is enabled

---

## Notification Thresholds

| Time Remaining | Notification |
|----------------|-------------|
| ≤ 60 min | ⚠️ First warning |
| ≤ 30 min | ⚠️ Second warning |
| ≤ 15 min | ⚠️ Third warning |
| ≤ 5 min | ⚠️ Final warning — save your work! |

Each threshold fires **once** per session. After the session resets (timer goes back above 60 min), thresholds automatically reset and the monitor starts watching again.

---

## Customizing Thresholds

Edit `claude-monitor.sh` and change the `for threshold in` line:

```bash
# Default: warn at 60, 30, 15, 5 minutes
for threshold in 60 30 15 5; do
```

Change the `StartInterval` in the plist to check more or less often:

```xml
<!-- 300 = every 5 minutes -->
<key>StartInterval</key>
<integer>300</integer>
```

---

## Managing the Service

```bash
# Stop the monitor
launchctl unload ~/Library/LaunchAgents/com.syam.claude-session-watch.plist

# Start it again
launchctl load ~/Library/LaunchAgents/com.syam.claude-session-watch.plist

# Check if it's loaded
launchctl list | grep claude

# View live log
tail -f ~/.claude_monitor.log

# View errors
cat ~/.claude_monitor_err.log
```

---

## Troubleshooting

### "Could not read Claude page"
- Is Chrome open? Is `claude.ai` open in a tab?
- Is **View → Developer → Allow JavaScript from Apple Events** enabled in Chrome?

### No notifications appearing
- Check **System Settings → Notifications** — make sure Terminal (or whichever app runs the script) is allowed to send notifications
- Test with: `osascript -e 'display notification "test" with title "Test"'`

### Script reads old/wrong time
- The script reads whichever `claude.ai` tab it finds first. Make sure you don't have multiple Claude tabs open.

---

## How the Scraping Works

The script uses **AppleScript** to execute JavaScript inside your logged-in Chrome tab:

```javascript
// Walks all text nodes in the DOM looking for "Resets in"
const walker = document.createTreeWalker(
  document.body, NodeFilter.SHOW_TEXT, null
);
let node;
while (node = walker.nextNode()) {
  const txt = node.textContent.trim();
  if (txt.match(/Resets in/i)) {
    return txt;  // e.g. "Resets in 2 hr 35 min"
  }
}
```

It then parses the hours and minutes and converts to total minutes remaining. No credentials are stored — it reads directly from your existing browser session.

---

## Privacy & Security

- ✅ No API keys or passwords stored
- ✅ No data sent anywhere — runs entirely locally
- ✅ Only reads your browser tab, doesn't modify anything
- ✅ Chrome's "Allow JavaScript from Apple Events" is scoped to the browser, not the internet

---

## License

MIT — use freely, modify as needed.
