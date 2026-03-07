#!/bin/bash
# Claude Session Monitor - One-Command Installer
# Usage: ./install.sh [--menubar]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Claude Session Monitor Installer    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.claude.session-monitor.plist"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
CONFIG_DIR="$HOME/.config/claude-monitor"

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${RED}Error: This tool only works on macOS${NC}"
  exit 1
fi

# Step 1: Make scripts executable
echo -e "${YELLOW}[1/5]${NC} Making scripts executable..."
chmod +x "$SCRIPT_DIR/claude-monitor.sh"
chmod +x "$SCRIPT_DIR/claude-usage.5m.sh" 2>/dev/null || true
echo -e "      ${GREEN}✓${NC} Done"

# Step 2: Create config directory
echo -e "${YELLOW}[2/5]${NC} Setting up config directory..."
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config" ]; then
  cp "$SCRIPT_DIR/config.example" "$CONFIG_DIR/config"
  echo -e "      ${GREEN}✓${NC} Created default config at $CONFIG_DIR/config"
else
  echo -e "      ${GREEN}✓${NC} Config already exists"
fi

# Step 3: Generate plist with correct paths
echo -e "${YELLOW}[3/5]${NC} Generating launchd plist..."
mkdir -p "$LAUNCH_AGENTS"

cat > "$LAUNCH_AGENTS/$PLIST_NAME" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.claude.session-monitor</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT_DIR/claude-monitor.sh</string>
  </array>

  <key>StartInterval</key>
  <integer>300</integer>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>$HOME/.claude_monitor.log</string>

  <key>StandardErrorPath</key>
  <string>$HOME/.claude_monitor_err.log</string>

  <key>KeepAlive</key>
  <false/>
</dict>
</plist>
EOF
echo -e "      ${GREEN}✓${NC} Created plist at $LAUNCH_AGENTS/$PLIST_NAME"

# Step 4: Unload old plist if exists, then load new one
echo -e "${YELLOW}[4/5]${NC} Loading launchd agent..."
launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME" 2>/dev/null || true
launchctl unload "$LAUNCH_AGENTS/com.syam.claude-session-watch.plist" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS/$PLIST_NAME"
echo -e "      ${GREEN}✓${NC} Agent loaded (runs every 5 minutes)"

# Step 5: Test run
echo -e "${YELLOW}[5/5]${NC} Running test..."
if bash "$SCRIPT_DIR/claude-monitor.sh"; then
  echo -e "      ${GREEN}✓${NC} Test completed"
else
  echo -e "      ${YELLOW}!${NC} Test ran (check if browser is open with Claude)"
fi

# Menu bar setup (optional)
if [[ "$1" == "--menubar" ]]; then
  echo ""
  echo -e "${YELLOW}Setting up menu bar plugin...${NC}"

  # Check for SwiftBar or xbar
  SWIFTBAR_PLUGINS="$HOME/Library/Application Support/SwiftBar/Plugins"
  XBAR_PLUGINS="$HOME/Library/Application Support/xbar/plugins"

  if [ -d "$SWIFTBAR_PLUGINS" ]; then
    ln -sf "$SCRIPT_DIR/claude-usage.5m.sh" "$SWIFTBAR_PLUGINS/claude-usage.5m.sh"
    echo -e "${GREEN}✓${NC} Menu bar plugin installed for SwiftBar"
  elif [ -d "$XBAR_PLUGINS" ]; then
    ln -sf "$SCRIPT_DIR/claude-usage.5m.sh" "$XBAR_PLUGINS/claude-usage.5m.sh"
    echo -e "${GREEN}✓${NC} Menu bar plugin installed for xbar"
  else
    echo -e "${YELLOW}!${NC} SwiftBar/xbar not found. Install from:"
    echo "   SwiftBar: https://github.com/swiftbar/SwiftBar"
    echo "   Then run: ./install.sh --menubar"
  fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Installation Complete!        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "The monitor is now running automatically every 5 minutes."
echo ""
echo "Configuration: $CONFIG_DIR/config"
echo "Logs:          ~/.claude_monitor.log"
echo ""
echo "Commands:"
echo "  View logs:    tail -f ~/.claude_monitor.log"
echo "  Stop:         launchctl unload ~/Library/LaunchAgents/$PLIST_NAME"
echo "  Start:        launchctl load ~/Library/LaunchAgents/$PLIST_NAME"
echo ""
if [[ "$1" != "--menubar" ]]; then
  echo "For menu bar widget: ./install.sh --menubar"
  echo "(Requires SwiftBar: brew install --cask swiftbar)"
  echo ""
fi
echo -e "${YELLOW}Note:${NC} Make sure a browser (Chrome/Arc/Safari) is open with Claude logged in."
