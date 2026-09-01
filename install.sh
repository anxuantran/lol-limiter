#!/bin/bash
# Installs lol-limiter: copies the script + config into place, registers a
# launchd agent that polls every 5s, and loads it.
#
# Usage: ./install.sh [daily_limit]   (default daily_limit: 3)

set -euo pipefail

BASE="$HOME/Library/Application Support/lol-limiter"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.lol-limiter.agent.plist"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SRC="$REPO_DIR/bin/lol-limiter.sh"
COMMON_SRC="$REPO_DIR/bin/common.sh"
OVERRIDE_SCRIPT_SRC="$REPO_DIR/bin/lol-limiter-override.sh"
OVERRIDE_DIALOG_SRC="$REPO_DIR/bin/override-dialog.js"
OVERRIDE_COUNTDOWN_SRC="$REPO_DIR/bin/override-countdown.js"
OVERRIDE_PASSAGE_SRC="$REPO_DIR/override-passage.txt"
PLIST_TEMPLATE="$REPO_DIR/com.lol-limiter.plist.template"

# Reuse a previously configured limit on reinstall/upgrade unless one is
# passed explicitly, so `git pull && ./install.sh` doesn't silently reset it.
EXISTING_LIMIT=""
if [ -f "$BASE/config.sh" ]; then
  EXISTING_LIMIT=$(grep -E '^DAILY_LIMIT=' "$BASE/config.sh" | head -1 | cut -d= -f2)
fi
DAILY_LIMIT="${1:-${EXISTING_LIMIT:-3}}"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "lol-limiter only works on macOS (it needs launchd + osascript)." >&2
  exit 1
fi

if ! [[ "$DAILY_LIMIT" =~ ^[0-9]+$ ]]; then
  echo "Daily limit must be a number, got: $DAILY_LIMIT" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing jq via Homebrew..."
    brew install jq
  else
    echo "jq is required but not installed, and Homebrew isn't available." >&2
    echo "Install jq (https://jqlang.org) and re-run this script." >&2
    exit 1
  fi
fi

APP_BUNDLE="/Applications/League of Legends.app"
if [ ! -d "$APP_BUNDLE" ]; then
  FOUND=$(find /Applications -maxdepth 2 -iname "League of Legends.app" 2>/dev/null | head -1)
  if [ -n "$FOUND" ]; then
    APP_BUNDLE="$FOUND"
  else
    echo "Warning: couldn't find League of Legends.app under /Applications." >&2
    echo "The limiter will silently do nothing until it's found at:" >&2
    echo "  $APP_BUNDLE/Contents/LoL/lockfile" >&2
    echo "Edit LCU_LOCKFILE in $BASE/config.sh once you know the real path." >&2
  fi
fi
LCU_LOCKFILE="$APP_BUNDLE/Contents/LoL/lockfile"

mkdir -p "$BASE"
cp "$SCRIPT_SRC" "$BASE/lol-limiter.sh"
cp "$COMMON_SRC" "$BASE/common.sh"
cp "$OVERRIDE_SCRIPT_SRC" "$BASE/lol-limiter-override.sh"
cp "$OVERRIDE_DIALOG_SRC" "$BASE/override-dialog.js"
cp "$OVERRIDE_COUNTDOWN_SRC" "$BASE/override-countdown.js"
chmod +x "$BASE/lol-limiter.sh" "$BASE/lol-limiter-override.sh"

# Never overwrite an existing passage — it's meant to be user-edited.
if [ ! -f "$BASE/override-passage.txt" ]; then
  cp "$OVERRIDE_PASSAGE_SRC" "$BASE/override-passage.txt"
fi

if [ ! -f "$BASE/config.sh" ]; then
  cat > "$BASE/config.sh" <<EOF
# lol-limiter config — edit and it takes effect on the next poll (~5s).
DAILY_LIMIT=$DAILY_LIMIT
LCU_LOCKFILE="$LCU_LOCKFILE"
# Wait after clicking "Override" before the passage prompt appears (seconds).
OVERRIDE_WAIT_SECONDS=900
EOF
else
  # Preserve any hand-edited config, just make sure DAILY_LIMIT reflects
  # what was requested this run (which itself defaults to the existing value).
  sed -i '' -E "s/^DAILY_LIMIT=.*/DAILY_LIMIT=$DAILY_LIMIT/" "$BASE/config.sh"
fi

if [ ! -f "$BASE/state.json" ]; then
  jq -n --arg d "$(date +%F)" '{date:$d, gameIds:[], count:0, locked:false, lastPhase:"None", wasRunningWhileLocked:false, bonusGames:0, overridePendingSince:0}' > "$BASE/state.json"
fi

# Unload any existing agent before (re)installing.
if launchctl print "gui/$(id -u)/com.lol-limiter.agent" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
fi

sed -e "s|__SCRIPT_PATH__|$BASE/lol-limiter.sh|g" \
    -e "s|__BASE_PATH__|$BASE|g" \
    "$PLIST_TEMPLATE" > "$LAUNCH_AGENT"

launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"

echo "lol-limiter installed."
echo "  Daily limit:  $DAILY_LIMIT games"
echo "  Lockfile:     $LCU_LOCKFILE"
echo "  State/log:    $BASE"
echo ""
echo "It's running now, polling every 5s. To change the limit, edit"
echo "  $BASE/config.sh"
echo ""
echo "Once locked, relaunching shows a dialog with an Override option: click"
echo "it (or run $BASE/lol-limiter-override.sh) to start a"
echo "wait, after which a passage prompt appears — typing it back exactly"
echo "grants one bonus game."
echo "To uninstall: ./uninstall.sh"
