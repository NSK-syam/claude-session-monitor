#!/bin/bash
# claude-monitor.sh
# Reads actual Claude session timer from claude.ai/settings/usage in Chrome.
# Fires Mac notifications at 60, 30, 15, 5 min before the session resets.
# Run every 5 min via launchd — fully automatic, no manual input.

STATE_FILE="$HOME/.claude_monitor_threshold"
LOG_FILE="$HOME/.claude_monitor.log"

# ── Helpers ────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M')] $*" >> "$LOG_FILE"; }

notify() {
  local title="$1" msg="$2"
  osascript -e "display notification \"$msg\" with title \"$title\" sound name \"Glass\""
  log "ALERT: $title — $msg"
}

# ── Scrape Claude settings page from Chrome ────────────────────────────────────

get_mins_remaining() {
  osascript <<'APPLESCRIPT'
tell application "Google Chrome"
  set result to ""
  repeat with w in windows
    repeat with t in tabs of w
      if URL of t contains "claude.ai" then
        -- Navigate to usage page if not already there
        if URL of t does not contain "settings/usage" then
          set URL of t to "https://claude.ai/settings/usage"
          delay 3
        end if
        set js to "
          (function() {
            const walker = document.createTreeWalker(
              document.body, NodeFilter.SHOW_TEXT, null
            );
            let node;
            while (node = walker.nextNode()) {
              const txt = node.textContent.trim();
              if (txt.match(/Resets in/i)) {
                return txt;
              }
            }
            return '';
          })()
        "
        set result to execute t javascript js
        if result is not "" then return result
      end if
    end repeat
  end repeat
  return result
end tell
APPLESCRIPT
}

# ── Parse "Resets in X hr Y min" or "Resets in Y min" → total minutes ─────────

parse_minutes() {
  local text="$1"
  local hours=0 mins=0

  if echo "$text" | grep -qE '[0-9]+ hr'; then
    hours=$(echo "$text" | grep -oE '[0-9]+ hr' | grep -oE '[0-9]+')
  fi
  if echo "$text" | grep -qE '[0-9]+ min'; then
    mins=$(echo "$text" | grep -oE '[0-9]+ min' | tail -1 | grep -oE '[0-9]+')
  fi

  echo $(( hours * 60 + mins ))
}

# ── Main ───────────────────────────────────────────────────────────────────────

RESET_TEXT=$(get_mins_remaining)

if [ -z "$RESET_TEXT" ]; then
  log "WARNING: Could not read Claude page — Chrome must be open and logged into claude.ai"
  exit 0
fi

MINS_LEFT=$(parse_minutes "$RESET_TEXT")

if [ "$MINS_LEFT" -eq 0 ]; then
  log "WARNING: Could not parse time from: '$RESET_TEXT'"
  exit 0
fi

log "Session: $MINS_LEFT min remaining (\"$RESET_TEXT\")"

# Load last notified threshold (default 999 = fresh / no alerts sent yet)
LAST_NOTIFIED=$(cat "$STATE_FILE" 2>/dev/null || echo 999)

# If we're back above 60 min, reset threshold tracker (new/reset session)
if [ "$MINS_LEFT" -gt 60 ]; then
  echo 999 > "$STATE_FILE"
  LAST_NOTIFIED=999
fi

# Fire each threshold once, descending (highest first so we don't double-fire)
for threshold in 60 30 15 5; do
  if [ "$MINS_LEFT" -le "$threshold" ] && [ "$LAST_NOTIFIED" -gt "$threshold" ]; then
    notify "⚠️ Claude Session" "${MINS_LEFT} min until session resets — save your work!"
    echo "$threshold" > "$STATE_FILE"
    log "Notified at $threshold-min threshold (actual: $MINS_LEFT min)"
    break
  fi
done
