#!/bin/bash
# lol-limiter: caps how many distinct League of Legends matches you can play per day.
#
# Polls the local League Client (LCU) API — https://127.0.0.1:<port>, the same
# local-only REST server the client uses internally — to count distinct match
# IDs played today. A mid-game crash/reconnect reuses the same match ID, so it
# never costs you an extra game. Once the configured limit is hit, the game
# that just ended triggers: kill Riot Client + League Client + the game
# process, and lock out relaunching until the date rolls over.
#
# Trying to relaunch while locked shows a dialog with an "Override" option.
# Clicking it starts a wait (OVERRIDE_WAIT_SECONDS, default 5 min) during
# which relaunch attempts keep getting killed as normal. Once the wait
# elapses, a passage-entry prompt appears on its own; typing it back exactly
# grants one bonus game and clears the lock.
#
# Nothing here talks to Riot's servers — only to 127.0.0.1 on your own machine.

set -uo pipefail

BASE="$HOME/Library/Application Support/lol-limiter"
STATE="$BASE/state.json"
CONFIG="$BASE/config.sh"
LOG="$BASE/limiter.log"
DIALOG_JS="$BASE/override-dialog.js"
PASSAGE_FILE="$BASE/override-passage.txt"

mkdir -p "$BASE"

# shellcheck source=/dev/null
[ -f "$CONFIG" ] && source "$CONFIG"

DAILY_LIMIT="${DAILY_LIMIT:-3}"
LCU_LOCKFILE="${LCU_LOCKFILE:-/Applications/League of Legends.app/Contents/LoL/lockfile}"
RIOT_PATTERN="${RIOT_PATTERN:-/Riot Games/Riot Client.app/}"
LOL_PATTERN="${LOL_PATTERN:-/League of Legends.app/}"
OVERRIDE_WAIT_SECONDS="${OVERRIDE_WAIT_SECONDS:-300}"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

today=$(date +%F)
init_state='{date:$d, gameIds:[], count:0, locked:false, lastPhase:"None", wasRunningWhileLocked:false, bonusGames:0, overridePendingSince:0}'

if [ ! -f "$STATE" ]; then
  jq -n --arg d "$today" "$init_state" > "$STATE"
fi

state_date=$(jq -r '.date' "$STATE")
if [ "$state_date" != "$today" ]; then
  jq -n --arg d "$today" "$init_state" > "$STATE"
  log "New day ($today) — counters reset."
fi

write_state() {
  jq "$@" "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
}

normalize() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

any_league_running() {
  pgrep -f "$RIOT_PATTERN" >/dev/null 2>&1 || pgrep -f "$LOL_PATTERN" >/dev/null 2>&1
}

kill_all_league() {
  pkill -TERM -f "$RIOT_PATTERN" 2>/dev/null
  pkill -TERM -f "$LOL_PATTERN" 2>/dev/null
  sleep 1
  pkill -KILL -f "$RIOT_PATTERN" 2>/dev/null
  pkill -KILL -f "$LOL_PATTERN" 2>/dev/null
}

locked=$(jq -r '.locked' "$STATE")
bonus_games=$(jq -r '.bonusGames // 0' "$STATE")
effective_limit=$((DAILY_LIMIT + bonus_games))
override_pending_since=$(jq -r '.overridePendingSince // 0' "$STATE")
now_epoch=$(date +%s)

# --- An override timer that has finished waiting fires on its own,
# regardless of whether anything is currently running. ---
if [ "$override_pending_since" -gt 0 ]; then
  elapsed=$((now_epoch - override_pending_since))
  if [ "$elapsed" -ge "$OVERRIDE_WAIT_SECONDS" ]; then
    log "Override wait complete — showing passage prompt."
    write_state '.overridePendingSince = 0'
    passage=$(cat "$PASSAGE_FILE" 2>/dev/null)
    result=$(osascript -l JavaScript "$DIALOG_JS" "$passage" 2>/dev/null)
    if [[ "$result" == OVERRIDE:* ]] && [ "$(normalize "${result#OVERRIDE:}")" = "$(normalize "$passage")" ]; then
      write_state '.bonusGames = ((.bonusGames // 0) + 1) | .locked = false | .wasRunningWhileLocked = false'
      log "Override SUCCESS — granted 1 bonus game."
      osascript -e 'display dialog "Unlocked one more game for today." with title "League Limiter" buttons {"OK"} default button "OK"' >/dev/null 2>&1
    else
      log "Override FAILED (mismatch or cancelled)."
      kill_all_league
      osascript -e 'display dialog "That did not match exactly (or was cancelled). Still locked — pick Override again from the lock dialog to retry." with title "League Limiter" buttons {"OK"} default button "OK" with icon stop' >/dev/null 2>&1
    fi
    exit 0
  fi
fi

if [ "$locked" = "true" ]; then
  if any_league_running; then
    was_notified=$(jq -r '.wasRunningWhileLocked' "$STATE")
    kill_all_league
    if [ "$was_notified" != "true" ]; then
      log "Relaunch attempt blocked while locked."
      if [ "$override_pending_since" -gt 0 ]; then
        remaining_min=$(( (OVERRIDE_WAIT_SECONDS - (now_epoch - override_pending_since) + 59) / 60 ))
        osascript -e "display dialog \"Still locked. Your override unlocks in about ${remaining_min} more minute(s) — a passage prompt will appear automatically then.\" with title \"League Limiter\" buttons {\"OK\"} default button \"OK\" with icon caution" >/dev/null 2>&1
      else
        btn=$(osascript -e "display dialog \"Nope — you're locked out for the rest of today ($effective_limit/$effective_limit games played).\n\nIt was closed again automatically.\" with title \"League Limiter\" buttons {\"OK\", \"Override\"} default button \"OK\" with icon caution" -e "button returned of result" 2>/dev/null)
        if [ "$btn" = "Override" ]; then
          write_state --arg t "$now_epoch" '.overridePendingSince = ($t | tonumber)'
          log "Override requested — ${OVERRIDE_WAIT_SECONDS}s timer started."
          osascript -e "display dialog \"Override started. A passage prompt will appear in $((OVERRIDE_WAIT_SECONDS / 60)) minute(s) — it'll pop up on its own, you don't need to do anything until then.\" with title \"League Limiter\" buttons {\"OK\"} default button \"OK\"" >/dev/null 2>&1
        fi
      fi
      write_state '.wasRunningWhileLocked = true'
    fi
  else
    write_state '.wasRunningWhileLocked = false'
  fi
  exit 0
fi

if [ ! -f "$LCU_LOCKFILE" ]; then
  exit 0
fi

IFS=: read -r _name _pid port password _protocol < "$LCU_LOCKFILE"

phase=$(curl -s -k --max-time 3 -u "riot:${password}" "https://127.0.0.1:${port}/lol-gameflow/v1/gameflow-phase" 2>/dev/null | tr -d '"')
[ -z "$phase" ] && phase="None"

last_phase=$(jq -r '.lastPhase' "$STATE")

if [ "$phase" = "InProgress" ] || [ "$phase" = "GameStart" ]; then
  game_id=$(curl -s -k --max-time 3 -u "riot:${password}" "https://127.0.0.1:${port}/lol-gameflow/v1/session" 2>/dev/null | jq -r '.gameData.gameId // empty')
  if [ -n "$game_id" ] && [ "$game_id" != "0" ]; then
    already_seen=$(jq --arg gid "$game_id" '.gameIds | index($gid) != null' "$STATE")
    if [ "$already_seen" != "true" ]; then
      write_state --arg gid "$game_id" '.gameIds += [$gid] | .count += 1'
      log "New match detected (gameId=$game_id). Count now $(jq -r '.count' "$STATE")/$effective_limit."
    fi
  fi
fi

case "$last_phase" in
  InProgress|WaitingForStats|PreEndOfGame|Reconnect)
    case "$phase" in
      EndOfGame|None|Lobby)
        count=$(jq -r '.count' "$STATE")
        if [ "$count" -ge "$effective_limit" ]; then
          log "Match #$count ended — hit daily limit ($effective_limit). Killing client and locking."
          kill_all_league
          write_state '.locked = true | .wasRunningWhileLocked = true'
          osascript -e "display dialog \"You've played $effective_limit games today.\n\nRiot Client and League have been closed and are locked until midnight.\" with title \"League Limiter\" buttons {\"OK\"} default button \"OK\" with icon caution" >/dev/null 2>&1
        fi
        ;;
    esac
    ;;
esac

write_state --arg p "$phase" '.lastPhase = $p'
exit 0
