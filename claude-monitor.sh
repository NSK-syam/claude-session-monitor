#!/bin/bash
# claude-monitor.sh
# Reads Claude session usage percentage from claude.ai/settings/usage.
# Tracks both Current Session and Weekly limits.
# Supports Chrome, Safari, and Arc browsers.
# Fires Mac notifications at configurable thresholds.
# Run every 5 min via launchd — fully automatic, no manual input.

# ── Config ─────────────────────────────────────────────────────────────────────

CONFIG_DIR="$HOME/.config/claude-monitor"
CONFIG_FILE="$CONFIG_DIR/config"
SESSION_STATE_FILE="$HOME/.claude_monitor_session"
WEEKLY_STATE_FILE="$HOME/.claude_monitor_weekly"
HISTORY_FILE="$HOME/.claude_monitor_history"
LOG_FILE="$HOME/.claude_monitor.log"

# Defaults (overridden by config file)
THRESHOLDS="10,20,30,40,50,60,70,80,90,100"
BROWSERS="chrome,arc,safari"

# Load config if exists
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

# ── Helpers ────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M')] $*" >> "$LOG_FILE"; }

notify() {
  local title="$1" msg="$2"
  osascript -e "display notification \"$msg\" with title \"$title\" sound name \"Glass\""
  log "ALERT: $title — $msg"
}

# ── Browser Scrapers ───────────────────────────────────────────────────────────

# Single-line JS to extract usage percentages using visible text (innerText)
# Uses indexOf to find "Current session" and "All models" headers to correctly
# assign session vs weekly percentages
USAGE_JS="(function(){var t=document.body.innerText;var m=t.match(/[0-9]+% used/ig);if(!m||m.length===0)return '';var s='';var w='';var si=t.indexOf('Current session');var wi=t.indexOf('All models');if(wi<0)wi=t.indexOf('Weekly limits');if(si>=0){for(var i=0;i<m.length;i++){var p=t.indexOf(m[i],si);if(p>=si&&(wi<0||p<wi)){s=m[i];break}}}if(wi>=0){for(var i=0;i<m.length;i++){var p=t.indexOf(m[i],wi);if(p>=wi&&(si<0||p>si+50)){w=m[i];break}}}if(!s&&m.length>0)s=m[0];if(!w&&m.length>1)w=m[1];return s+'|'+w})()"

get_usage_from_chrome() {
  osascript <<EOF 2>/dev/null
tell application "System Events"
  if not (exists process "Google Chrome") then return ""
end tell
tell application "Google Chrome"
  set lastResult to ""
  repeat with w in windows
    repeat with t in tabs of w
      if URL of t contains "claude.ai" then
        if URL of t does not contain "settings/usage" then
          set URL of t to "https://claude.ai/settings/usage"
          delay 3
        end if
        set r to execute t javascript "${USAGE_JS}"
        if r is not "" then set lastResult to r
      end if
    end repeat
  end repeat
  return lastResult
end tell
EOF
}

get_usage_from_arc() {
  osascript <<EOF 2>/dev/null
tell application "System Events"
  if not (exists process "Arc") then return ""
end tell
tell application "Arc"
  set lastResult to ""
  repeat with w in windows
    repeat with t in tabs of w
      if URL of t contains "claude.ai" then
        if URL of t does not contain "settings/usage" then
          set URL of t to "https://claude.ai/settings/usage"
          delay 3
        end if
        set r to execute t javascript "${USAGE_JS}"
        if r is not "" then set lastResult to r
      end if
    end repeat
  end repeat
  return lastResult
end tell
EOF
}

get_usage_from_safari() {
  osascript <<EOF 2>/dev/null
tell application "System Events"
  if not (exists process "Safari") then return ""
end tell
tell application "Safari"
  set lastResult to ""
  repeat with w in windows
    repeat with t in tabs of w
      if URL of t contains "claude.ai" then
        if URL of t does not contain "settings/usage" then
          set URL of t to "https://claude.ai/settings/usage"
          delay 3
        end if
        set r to do JavaScript "${USAGE_JS}" in t
        if r is not "" then set lastResult to r
      end if
    end repeat
  end repeat
  return lastResult
end tell
EOF
}

# Try browsers in configured order
get_usage_percents() {
  local IFS=','
  for browser in $BROWSERS; do
    case "$browser" in
      chrome) result=$(get_usage_from_chrome) ;;
      arc)    result=$(get_usage_from_arc) ;;
      safari) result=$(get_usage_from_safari) ;;
    esac
    if [ -n "$result" ]; then
      echo "$result"
      return
    fi
  done
  echo ""
}

# ── Parse "X% used" → percentage number ───────────────────────────────────────

parse_percent() {
  local text="$1"
  echo "$text" | grep -oE '^[0-9]+' || echo 0
}

# ── Usage Prediction ──────────────────────────────────────────────────────────

update_history() {
  local percent="$1"
  local timestamp=$(date +%s)

  # Append to history
  echo "$timestamp,$percent" >> "$HISTORY_FILE"

  # Keep only last 20 entries
  tail -20 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

predict_time_to_full() {
  local current_percent="$1"

  # Need at least 2 data points
  local count=$(wc -l < "$HISTORY_FILE" 2>/dev/null | tr -d ' ')
  if [ "${count:-0}" -lt 2 ]; then
    echo ""
    return
  fi

  # Get oldest and newest entries
  local oldest=$(head -1 "$HISTORY_FILE")
  local newest=$(tail -1 "$HISTORY_FILE")

  local old_time=$(echo "$oldest" | cut -d',' -f1)
  local old_percent=$(echo "$oldest" | cut -d',' -f2)
  local new_time=$(echo "$newest" | cut -d',' -f1)
  local new_percent=$(echo "$newest" | cut -d',' -f2)

  # Calculate rate (percent per second)
  local time_diff=$((new_time - old_time))
  local percent_diff=$((new_percent - old_percent))

  # If no increase or negative (session reset), can't predict
  if [ "$percent_diff" -le 0 ] || [ "$time_diff" -le 0 ]; then
    echo ""
    return
  fi

  # Calculate seconds until 100%
  local remaining=$((100 - current_percent))
  local seconds_to_full=$(( (remaining * time_diff) / percent_diff ))

  # Convert to human readable
  if [ "$seconds_to_full" -lt 60 ]; then
    echo "<1 min"
  elif [ "$seconds_to_full" -lt 3600 ]; then
    echo "$((seconds_to_full / 60)) min"
  else
    local hours=$((seconds_to_full / 3600))
    local mins=$(( (seconds_to_full % 3600) / 60 ))
    echo "${hours}h ${mins}m"
  fi
}

# ── Check and notify for a single metric ──────────────────────────────────────

check_threshold() {
  local name="$1"
  local percent="$2"
  local state_file="$3"
  local prediction="$4"

  # Load last notified threshold (default 0 = no alerts sent yet)
  local last_notified=$(cat "$state_file" 2>/dev/null || echo 0)

  # If usage dropped below last notified threshold, reset (new session/week)
  if [ "$percent" -lt "$last_notified" ]; then
    echo 0 > "$state_file"
    last_notified=0
    # Clear history on session reset
    if [ "$name" = "Session" ]; then
      rm -f "$HISTORY_FILE"
    fi
  fi

  # Fire notification at each configured threshold
  local IFS=','
  for threshold in $THRESHOLDS; do
    if [ "$percent" -ge "$threshold" ] && [ "$last_notified" -lt "$threshold" ]; then
      local msg="${percent}% used — ${threshold}% threshold"
      if [ -n "$prediction" ] && [ "$name" = "Session" ]; then
        msg="$msg (~$prediction to limit)"
      fi
      notify "⚠️ Claude $name" "$msg"
      echo "$threshold" > "$state_file"
      log "$name: Notified at $threshold% (actual: $percent%)"
      break
    fi
  done
}

# ── Main ───────────────────────────────────────────────────────────────────────

USAGE_TEXT=$(get_usage_percents)

if [ -z "$USAGE_TEXT" ]; then
  log "WARNING: Could not read Claude page — browser must be open and logged into claude.ai"
  exit 0
fi

# Split the two percentages (session|weekly)
SESSION_TEXT=$(echo "$USAGE_TEXT" | cut -d'|' -f1)
WEEKLY_TEXT=$(echo "$USAGE_TEXT" | cut -d'|' -f2)

SESSION_PERCENT=$(parse_percent "$SESSION_TEXT")
WEEKLY_PERCENT=$(parse_percent "$WEEKLY_TEXT")

# Update history for prediction
update_history "$SESSION_PERCENT"
PREDICTION=$(predict_time_to_full "$SESSION_PERCENT")

log "Current Session: $SESSION_PERCENT% | Weekly: $WEEKLY_PERCENT%${PREDICTION:+ | ETA: ~$PREDICTION}"

# Check thresholds for both session and weekly
if [ -n "$SESSION_TEXT" ]; then
  check_threshold "Session" "$SESSION_PERCENT" "$SESSION_STATE_FILE" "$PREDICTION"
fi

if [ -n "$WEEKLY_TEXT" ]; then
  check_threshold "Weekly" "$WEEKLY_PERCENT" "$WEEKLY_STATE_FILE" ""
fi
