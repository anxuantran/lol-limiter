#!/bin/bash
# Removes the launchd agent. Leaves state.json/config.sh/logs in place by
# default (pass --purge to delete those too).

set -euo pipefail

BASE="$HOME/Library/Application Support/lol-limiter"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.lol-limiter.agent.plist"

if launchctl print "gui/$(id -u)/com.lol-limiter.agent" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
fi
rm -f "$LAUNCH_AGENT"

echo "launchd agent removed."

if [[ "${1:-}" == "--purge" ]]; then
  rm -rf "$BASE"
  echo "Removed $BASE (state, config, logs)."
else
  echo "Left $BASE in place (state/config/logs). Pass --purge to delete it too."
fi
