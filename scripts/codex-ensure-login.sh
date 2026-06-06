#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

status_output="$(scripts/codex-status.sh 2>&1 || true)"
printf '%s\n' "$status_output"

if printf '%s\n' "$status_output" | grep -q '^Logged in using ChatGPT'; then
  exit 0
fi

echo
echo "Codex is not logged in. Starting callback login..."
exec scripts/codex-login.sh
