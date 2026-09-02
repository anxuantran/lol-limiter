#!/bin/bash
# Bootstrap installer: downloads lol-limiter without requiring git, then runs
# the real install.sh. Meant to be piped from curl:
#
#   curl -fsSL https://raw.githubusercontent.com/anxuantran/zhonyas/main/install-remote.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/anxuantran/zhonyas/main/install-remote.sh | bash -s -- 5
#
# Pass a daily limit as the first arg, same as install.sh.

set -euo pipefail

REPO="anxuantran/zhonyas"
REF="${LOL_LIMITER_REF:-main}"
TARBALL_URL="https://codeload.github.com/$REPO/tar.gz/refs/heads/$REF"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "lol-limiter only works on macOS (it needs launchd + osascript)." >&2
  exit 1
fi

for cmd in curl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lol-limiter-install.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading lol-limiter ($REF)..."
curl -fsSL "$TARBALL_URL" -o "$TMP_DIR/lol-limiter.tar.gz"
tar -xzf "$TMP_DIR/lol-limiter.tar.gz" -C "$TMP_DIR"

SRC_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)"
if [ -z "$SRC_DIR" ]; then
  echo "Couldn't find extracted source under $TMP_DIR" >&2
  exit 1
fi

"$SRC_DIR/install.sh" "$@"
