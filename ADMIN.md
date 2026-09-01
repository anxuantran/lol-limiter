# Changing the limit / uninstalling

## Changing the limit

Edit `~/Library/Application Support/lol-limiter/config.sh`:

```sh
DAILY_LIMIT=3
LCU_LOCKFILE="/Applications/League of Legends.app/Contents/LoL/lockfile"
OVERRIDE_WAIT_SECONDS=900
```

Changes take effect on the next poll (within ~5s) — no reinstall needed.

## Uninstall

```
./uninstall.sh          # removes the background agent
./uninstall.sh --purge  # also deletes state/config/logs
```
