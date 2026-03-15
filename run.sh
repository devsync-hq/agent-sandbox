#!/usr/bin/env bash
set -euo pipefail

WORKSPACE=$(realpath "${1:-$PWD}")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SETTINGS_FILE="$WORKSPACE/.claude/settings.local.json"

# Prerequisite check: bubblewrap required on Linux/WSL2
if [[ "$(uname -s)" == "Linux" ]]; then
  if ! command -v bwrap &>/dev/null; then
    echo "ERROR: bubblewrap is not installed. Claude Code's built-in sandbox requires it on Linux/WSL2."
    echo ""
    echo "Install with:"
    echo "  sudo apt-get install bubblewrap socat"
    exit 1
  fi
fi

# Backup existing settings or mark as absent
SETTINGS_EXISTED=false
SETTINGS_BACKUP=""
if [[ -f "$SETTINGS_FILE" ]]; then
  SETTINGS_EXISTED=true
  SETTINGS_BACKUP=$(cat "$SETTINGS_FILE")
fi

# Trap EXIT to restore settings to pre-run state
cleanup() {
  if [[ "$SETTINGS_EXISTED" == "true" ]]; then
    echo "$SETTINGS_BACKUP" > "$SETTINGS_FILE"
  else
    rm -f "$SETTINGS_FILE"
  fi
}
trap cleanup EXIT

# Merge sandbox-settings.json into settings.local.json
mkdir -p "$WORKSPACE/.claude"
if [[ "$SETTINGS_EXISTED" == "true" ]]; then
  python3 -c "
import sys, json
s = json.load(open('$SETTINGS_FILE'))
s['sandbox'] = json.load(open('$SCRIPT_DIR/sandbox-settings.json'))['sandbox']
json.dump(s, sys.stdout, indent=2)
" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
else
  cp "$SCRIPT_DIR/sandbox-settings.json" "$SETTINGS_FILE"
fi

cd "$WORKSPACE" && exec claude --dangerously-skip-permissions
