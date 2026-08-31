#!/bin/bash
# Manual escape hatch: shows the override passage in a native dialog, and if
# you type it back exactly, grants exactly ONE bonus game for today and lifts
# the lock. Run it again for a second bonus game, and so on — each one costs
# the same ritual.

set -uo pipefail

BASE="$HOME/Library/Application Support/lol-limiter"
STATE="$BASE/state.json"
PASSAGE_FILE="$BASE/override-passage.txt"
DIALOG_JS="$BASE/override-dialog.js"
LOG="$BASE/limiter.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

if [ ! -f "$PASSAGE_FILE" ]; then
  echo "Missing $PASSAGE_FILE" >&2
  exit 1
fi
if [ ! -f "$DIALOG_JS" ]; then
  echo "Missing $DIALOG_JS" >&2
  exit 1
fi
if [ ! -f "$STATE" ]; then
  echo "Missing $STATE — is lol-limiter installed? (run install.sh)" >&2
  exit 1
fi

passage=$(cat "$PASSAGE_FILE")

result=$(osascript -l JavaScript "$DIALOG_JS" "$passage")

if [[ "$result" != OVERRIDE:* ]]; then
  log "Override attempt cancelled."
  exit 0
fi

typed="${result#OVERRIDE:}"

# Trim leading/trailing whitespace of the whole block only — internal
# content must match exactly, word for word.
normalize() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

if [ "$(normalize "$typed")" != "$(normalize "$passage")" ]; then
  log "Override attempt FAILED (text did not match)."
  osascript -e 'display dialog "That did not match exactly. Run the override again to retry." with title "League Limiter" buttons {"OK"} default button "OK" with icon stop' >/dev/null 2>&1
  exit 1
fi

jq '.bonusGames = ((.bonusGames // 0) + 1) | .locked = false | .wasRunningWhileLocked = false' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
new_bonus=$(jq -r '.bonusGames' "$STATE")
log "Override SUCCESS — granted 1 bonus game (bonusGames now $new_bonus)."
osascript -e 'display dialog "Unlocked one more game for today." with title "League Limiter" buttons {"OK"} default button "OK"' >/dev/null 2>&1
