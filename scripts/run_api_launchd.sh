#!/bin/zsh
# LaunchAgent entrypoint for PlnFlr on mini-m4-0.
cd /Users/mini-m4-main/Developer/OSS/PlnFlr || cd "$(dirname "$0")/.."
export PATH="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"
UV_BIN="$(command -v uv || true)"
if [ -z "$UV_BIN" ] && [ -x "${HOME}/.local/bin/uv" ]; then
  UV_BIN="${HOME}/.local/bin/uv"
fi
if [ -z "$UV_BIN" ]; then
  echo "uv not found in PATH" >&2
  exit 1
fi
PORT="${PORT:-8004}"
exec "$UV_BIN" run uvicorn plnflr.main:app --host 0.0.0.0 --port "$PORT"
