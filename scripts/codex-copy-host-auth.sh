#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

if [ ! -f "$HOME/.codex/auth.json" ]; then
	echo "missing $HOME/.codex/auth.json; run 'codex login' on macOS first" >&2
	exit 1
fi

mkdir -p data/codex
chmod 700 data/codex 2>/dev/null || true
cp "$HOME/.codex/auth.json" data/codex/auth.json
chmod 600 data/codex/auth.json

if [ ! -f data/codex/config.toml ]; then
	cat >data/codex/config.toml <<'EOF'
cli_auth_credentials_store = "file"
forced_login_method = "chatgpt"
EOF
fi

echo "copied macOS Codex auth cache into data/codex/auth.json"
