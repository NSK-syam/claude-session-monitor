#!/bin/bash
# claude-monitor.sh
# Reads Claude session usage percentage from claude.ai/settings/usage in Chrome.
# Tracks both Current Session and Weekly limits.
# Fires Mac notifications every 10% usage (10%, 20%, 30%, ... 100%).
# Run every 5 min via launchd — fully automatic, no manual input.

SESSION_STATE_FILE="$HOME/.claude_monitor_session"
WEEKLY_STATE_FILE="$HOME/.claude_monitor_weekly"
LOG_FILE="$HOME/.claude_monitor.log"

# ── Helpers ────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M')] $*" >> "$LOG_FILE"; }

notify() {
  local title="$1" msg="$2"
  osascript -e "display notification \"$msg\" with title \"$title\" sound name \"Glass\""
  log "ALERT: $title — $msg"
}

# ── Scrape Claude settings page from Chrome ────────────────────────────────────

get_usage_percents() {
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
            let percentages = [];
            while (node = walker.nextNode()) {
              const txt = node.textContent.trim();
              // Look for 'X% used' patterns
              if (txt.match(/^\\d+% used$/i)) {
                percentages.push(txt);
              }
            }
            // Return first two: session and weekly
            return percentages.slice(0, 2).join('|');
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

# ── Parse "X% used" → percentage number ───────────────────────────────────────

parse_percent() {
  local text="$1"
  echo "$text" | grep -oE '^[0-9]+' || echo 0
}

# ── Check and notify for a single metric ──────────────────────────────────────

check_threshold() {
  local name="$1"
  local percent="$2"
  local state_file="$3"

  # Load last notified threshold (default 0 = no alerts sent yet)
  local last_notified=$(cat "$state_file" 2>/dev/null || echo 0)

  # If usage dropped below last notified threshold, reset (new session/week)
  if [ "$percent" -lt "$last_notified" ]; then
    echo 0 > "$state_file"
    last_notified=0
  fi

  # Fire notification at each 10% threshold (10, 20, 30, ... 100)
  for threshold in 10 20 30 40 50 60 70 80 90 100; do
    if [ "$percent" -ge "$threshold" ] && [ "$last_notified" -lt "$threshold" ]; then
      notify "⚠️ Claude $name" "${percent}% used — ${threshold}% threshold reached"
      echo "$threshold" > "$state_file"
      log "$name: Notified at $threshold% threshold (actual: $percent%)"
      break
    fi
  done
}

# ── Main ───────────────────────────────────────────────────────────────────────

USAGE_TEXT=$(get_usage_percents)

if [ -z "$USAGE_TEXT" ]; then
  log "WARNING: Could not read Claude page — Chrome must be open and logged into claude.ai"
  exit 0
fi

# Split the two percentages (session|weekly)
SESSION_TEXT=$(echo "$USAGE_TEXT" | cut -d'|' -f1)
WEEKLY_TEXT=$(echo "$USAGE_TEXT" | cut -d'|' -f2)

SESSION_PERCENT=$(parse_percent "$SESSION_TEXT")
WEEKLY_PERCENT=$(parse_percent "$WEEKLY_TEXT")

log "Current Session: $SESSION_PERCENT% | Weekly: $WEEKLY_PERCENT%"

# Check thresholds for both
if [ -n "$SESSION_TEXT" ]; then
  check_threshold "Session" "$SESSION_PERCENT" "$SESSION_STATE_FILE"
fi

if [ -n "$WEEKLY_TEXT" ]; then
  check_threshold "Weekly" "$WEEKLY_PERCENT" "$WEEKLY_STATE_FILE"
fi
