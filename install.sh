#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.claude"

echo "Claude-Statusline-Pro-Max Installer"
echo "===================================="
echo ""

# Check dependencies
missing=()
command -v jq &>/dev/null || missing+=("jq")
command -v bash &>/dev/null || missing+=("bash")

if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing dependencies: ${missing[*]}"
  echo "Install with: brew install ${missing[*]}"
  exit 1
fi

# Copy statusline script
echo "Installing statusline-command.sh -> $TARGET_DIR/statusline-command.sh"
cp "$SCRIPT_DIR/statusline-command.sh" "$TARGET_DIR/statusline-command.sh"
chmod +x "$TARGET_DIR/statusline-command.sh"

# Configure settings.json
SETTINGS="$TARGET_DIR/settings.json"

if [ -f "$SETTINGS" ]; then
  echo ""
  echo "Found existing settings.json at $SETTINGS"
  echo ""
  echo "Add the following to your settings.json:"
  echo ""
  echo '  "statusLine": {'
  echo '    "type": "command",'
  echo '    "command": "bash ~/.claude/statusline-command.sh",'
  echo '    "refreshInterval": 5'
  echo '  }'
  echo ""
  echo "Or run: ./install.sh --write-config"
  echo ""

  if [ "${1:-}" = "--write-config" ]; then
    if command -v node &>/dev/null; then
      node -e "
        const fs = require('fs');
        const p = '$SETTINGS';
        const s = JSON.parse(fs.readFileSync(p, 'utf8'));
        s.statusLine = { type: 'command', command: 'bash ~/.claude/statusline-command.sh', refreshInterval: 5 };
        fs.writeFileSync(p, JSON.stringify(s, null, 2) + '\n');
        console.log('Updated settings.json with statusLine config');
      "
    else
      echo "Node.js not found. Please manually add the statusLine config to $SETTINGS"
    fi
  fi
else
  echo "No settings.json found. Creating minimal config..."
  mkdir -p "$TARGET_DIR"
  cat > "$SETTINGS" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 5
  }
}
EOF
  echo "Created $SETTINGS with statusLine config"
fi

echo ""
echo "Done! Restart Claude Code to see the new statusline."
