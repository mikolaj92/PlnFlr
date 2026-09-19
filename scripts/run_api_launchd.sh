#!/bin/zsh
# LaunchAgent entrypoint for PlnFlr on mini-m4-0.
ROOT="/Users/mini-m4-0/Developer/OSS/PlnFlr"
cd "$ROOT" || cd "$(dirname "$0")/.."
export PATH="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"
PORT="${PORT:-8004}"
export PORT
BIN="$(swift build --package-path Web --show-bin-path)/PlnFlrServe"
if [ ! -x "$BIN" ]; then
  swift build --package-path Web
  BIN="$(swift build --package-path Web --show-bin-path)/PlnFlrServe"
fi
exec "$BIN"
