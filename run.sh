#!/usr/bin/env bash
set -euo pipefail

WORKSPACE=$(realpath "${1:-$PWD}")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
AGENT="${AGENT:-claude}"

# Prerequisite check: bubblewrap required on Linux/WSL2
if [[ "$(uname -s)" == "Linux" ]]; then
  if ! command -v bwrap &>/dev/null; then
    echo "ERROR: bubblewrap is not installed. The agent sandbox requires it on Linux/WSL2."
    echo ""
    echo "Install with:"
    echo "  sudo apt-get install bubblewrap socat"
    exit 1
  fi
fi

# Settings file only applies to Claude
if [[ "$AGENT" == "claude" ]]; then
  SETTINGS_FILE="$WORKSPACE/.claude/settings.local.json"
else
  SETTINGS_FILE=""
fi

# Backup existing settings or mark as absent (Claude only)
SETTINGS_EXISTED=false
SETTINGS_BACKUP=""
if [[ -n "$SETTINGS_FILE" && -f "$SETTINGS_FILE" ]]; then
  SETTINGS_EXISTED=true
  SETTINGS_BACKUP=$(cat "$SETTINGS_FILE")
fi

# Trap EXIT to restore settings to pre-run state (Claude only)
cleanup() {
  if [[ -n "$SETTINGS_FILE" ]]; then
    if [[ "$SETTINGS_EXISTED" == "true" ]]; then
      echo "$SETTINGS_BACKUP" > "$SETTINGS_FILE"
    else
      rm -f "$SETTINGS_FILE"
    fi
  fi
}
trap cleanup EXIT

# Merge sandbox-settings.json into settings.local.json (Claude only)
if [[ -n "$SETTINGS_FILE" ]]; then
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
fi

cd "$WORKSPACE"
case "$AGENT" in
  claude)
    exec claude --dangerously-skip-permissions
    ;;
  gemini)
    exec gemini --yolo
    ;;
  *)
    echo "ERROR: Unknown agent '${AGENT}'. Valid values: claude, gemini"
    exit 1
    ;;
esac
