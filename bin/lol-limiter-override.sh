#!/bin/bash
# Manually starts the override wait (same as clicking "Override" on the lock
# dialog) without needing to trigger it by relaunching Riot Client first.
# Does NOT show the passage prompt itself — the main poller does that once
# the wait elapses, so this can't be used to skip the wait.

set -uo pipefail

BASE="$HOME/Library/Application Support/lol-limiter"
STATE="$BASE/state.json"
CONFIG="$BASE/config.sh"
LOG="$BASE/limiter.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

if [ ! -f "$STATE" ]; then
  echo "Missing $STATE — is lol-limiter installed? (run install.sh)" >&2
  exit 1
fi

# shellcheck source=/dev/null
[ -f "$CONFIG" ] && source "$CONFIG"
OVERRIDE_WAIT_SECONDS="${OVERRIDE_WAIT_SECONDS:-300}"

now=$(date +%s)
pending=$(jq -r '.overridePendingSince // 0' "$STATE")

if [ "$pending" -gt 0 ]; then
  remaining_min=$(( (OVERRIDE_WAIT_SECONDS - (now - pending) + 59) / 60 ))
  echo "An override is already counting down (~${remaining_min} more minute(s))."
  exit 0
fi

jq --arg t "$now" '.overridePendingSince = ($t | tonumber)' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
log "Override timer started manually via CLI."
echo "Override timer started. A passage prompt will appear in $((OVERRIDE_WAIT_SECONDS / 60)) minutes."
