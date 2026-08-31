# Shared helpers for lol-limiter.sh and lol-limiter-override.sh.
# Caller must set BASE, STATE, LOG before sourcing this.

STATE_LOCK="$BASE/.state.lock"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

# mkdir is atomic on a POSIX filesystem, so it doubles as a lock: only one
# process can successfully mkdir a given path at once. This matters because
# the main poller and a detached background handler (the passage prompt, the
# countdown) can all be alive and writing state.json at the same time — an
# unguarded read-modify-write here is a real lost-update race, not a
# theoretical one (it's what caused overridePromptActive to get stuck true).
acquire_state_lock() {
  local tries=0
  while ! mkdir "$STATE_LOCK" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then
      # ~10s of contention almost certainly means a stale lock from a
      # writer that crashed mid-update, not real contention. Force through
      # rather than hang forever.
      rmdir "$STATE_LOCK" 2>/dev/null
    fi
    sleep 0.1
  done
}

release_state_lock() {
  rmdir "$STATE_LOCK" 2>/dev/null
}

write_state() {
  acquire_state_lock
  jq "$@" "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  release_state_lock
}

normalize() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}
