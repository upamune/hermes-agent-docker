#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

install -d -m 700 data/codex

if [ ! -f data/codex/config.toml ]; then
	cat >data/codex/config.toml <<'EOF'
cli_auth_credentials_store = "file"
forced_login_method = "chatgpt"
EOF
fi

docker compose up -d hermes hermes-dashboard-proxy codex-login-proxy
docker exec hermes sh -lc 'pkill -f "[c]odex login" || true'

cleanup() {
	docker compose stop codex-login-proxy >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

echo "Starting Codex ChatGPT login inside the Hermes container."
echo "Open the printed auth URL in your macOS browser."
echo "Do not use --device-auth, and do not paste callback URLs into chat."
echo

docker exec -i hermes sh -lc 'HOME=/opt/data/home CODEX_HOME=/opt/data/home/.codex codex login'
scripts/hermes-import-codex-auth.sh
