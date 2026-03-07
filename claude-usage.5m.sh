#!/bin/bash
# <xbar.title>Claude Usage Monitor</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Claude Session Monitor</xbar.author>
# <xbar.desc>Shows Claude AI usage in menu bar</xbar.desc>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

LOG_FILE="$HOME/.claude_monitor.log"

# Parse latest log entry
if [ -f "$LOG_FILE" ]; then
  LATEST_LINE=$(grep "Current Session:" "$LOG_FILE" | tail -1)
  SESSION=$(echo "$LATEST_LINE" | grep -oE 'Session: [0-9]+%' | grep -oE '[0-9]+')
  WEEKLY=$(echo "$LATEST_LINE" | grep -oE 'Weekly: [0-9]+%' | grep -oE '[0-9]+')
  ETA=$(echo "$LATEST_LINE" | grep -oE 'ETA: ~[^|]+' | sed 's/ETA: ~//')
fi

SESSION=${SESSION:-"?"}
WEEKLY=${WEEKLY:-"?"}

# Color based on session usage
if [ "$SESSION" != "?" ]; then
  if [ "$SESSION" -ge 80 ]; then
    COLOR="#ff4444"
  elif [ "$SESSION" -ge 50 ]; then
    COLOR="#ffaa00"
  else
    COLOR="#44bb44"
  fi
else
  COLOR="#888888"
fi

# Menu bar title
echo "☁️ ${SESSION}% | color=$COLOR"
echo "---"
echo "Current Session: ${SESSION}% used | color=$COLOR"
echo "Weekly Limit: ${WEEKLY}% used"
if [ -n "$ETA" ]; then
  echo "Est. time to limit: ~$ETA"
fi
echo "---"
echo "Open Claude | href=https://claude.ai"
echo "Usage Settings | href=https://claude.ai/settings/usage"
echo "---"
echo "View Log | bash='tail -30 ~/.claude_monitor.log' terminal=true"
echo "Refresh Now | bash='$HOME/claude-session-monitor/claude-monitor.sh' terminal=false refresh=true"
echo "---"
echo "Refresh | refresh=true"
