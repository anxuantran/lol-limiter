# lol-limiter

<p align="center">
  <img width="378" height="498" alt="image" src="https://github.com/user-attachments/assets/85059810-90e7-4513-b9f8-2aa8e822901a" />
</p>

<p align="center"><i>“The value you receive from a pursuit is often proportional to the energy invested”</i></p>

A macOS tool that caps how many League of Legends matches you can play in a
day. Once you hit the limit, it closes Riot Client + League Client + the
game, and locks out relaunching until midnight.

Not affiliated with Riot Games. Doesn't touch Riot's servers or your account
— it only talks to `127.0.0.1`, the same local API the League Client itself
uses.

## How it works

The League Client runs a local REST API (the "LCU API") on `127.0.0.1`,
authenticated via a lockfile at
`/Applications/League of Legends.app/Contents/LoL/lockfile`. A background
agent polls it every 5 seconds and reads the current match's `gameId`.

Each **distinct** `gameId` seen counts as one game. If your client crashes
mid-match and you reconnect, the League server hands you back the *same*
`gameId` — so a crash-reconnect never costs you an extra game. A genuinely
new match always gets a new one.

When the game that pushes you over the limit ends, the agent:
1. Kills Riot Client, League Client, and the game process.
2. Locks — any further relaunch attempt gets killed again within ~5s, so you
   can't get far enough to queue for another game.
3. Shows a confirmation dialog.

The lock clears automatically at midnight (local time).

## Install
### Windows
You have bigger problems than League my friend.

### MacOS
No git clone needed — download and run the installer directly:

```
curl -fsSL https://raw.githubusercontent.com/anxuantran/zhonyas/main/install-remote.sh | bash
curl -fsSL https://raw.githubusercontent.com/anxuantran/zhonyas/main/install-remote.sh | bash -s -- 3   # custom limit
```

It downloads the repo to a temp dir, runs `install.sh`, and cleans up after
itself. If you'd rather clone the repo yourself first (e.g. to read the
scripts before running them):

```
git clone https://github.com/anxuantran/zhonyas.git
cd zhonyas
./install.sh          # defaults to a 3-game daily limit
./install.sh 5         # or set your own limit
```

Requires macOS + [jq](https://jqlang.org) (installed automatically via
Homebrew if missing).

## Notes

- Only checked on stock macOS installs of League. If yours lives somewhere
  other than `/Applications/League of Legends.app`, `install.sh` will warn
  you and you can fix the path in `config.sh`.
- State (today's game count, lock status) lives in
  `~/Library/Application Support/lol-limiter/state.json`. Logs are in the
  same directory (`limiter.log`, `launchd.out.log`, `launchd.err.log`).
- This is a self-imposed limiter, not a security boundary — it's friction
  against "just one more game," not a lock you can't pick.
- Uninstalling or changing your limit: see `ADMIN.md`.
