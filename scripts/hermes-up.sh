#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

run_setup=false
force_setup=false
skip_setup=false
if [ "${1:-}" = "--setup" ]; then
	run_setup=true
	force_setup=true
elif [ "${1:-}" = "--no-setup" ]; then
	skip_setup=true
elif [ "${1:-}" != "" ]; then
	echo "usage: scripts/hermes-up.sh [--setup|--no-setup]" >&2
	exit 2
fi

mkdir -p data/hermes/home
install -d -m 700 data/codex
scripts/render-squid-config.sh

if [ ! -f data/hermes/config.yaml ] && [ -f templates/hermes-config.yaml ]; then
	if [ -f templates/hermes-config-mcp.yaml ]; then
		python3 scripts/render-hermes-config.py templates/hermes-config.yaml data/hermes/config.yaml templates/hermes-config-mcp.yaml
		echo "created data/hermes/config.yaml from templates/hermes-config.yaml + templates/hermes-config-mcp.yaml"
	else
		python3 scripts/render-hermes-config.py templates/hermes-config.yaml data/hermes/config.yaml
		echo "created data/hermes/config.yaml from templates/hermes-config.yaml"
	fi
fi

if [ "$skip_setup" = false ] && [ "$force_setup" = false ] && [ ! -f data/hermes/config.yaml ]; then
	run_setup=true
fi

if [ ! -f .env ]; then
	cp .env.example .env
	echo "created .env from .env.example"
fi

docker compose build hermes
docker compose up -d --remove-orphans
docker compose stop codex-login-proxy >/dev/null 2>&1 || true
if [ -f data/codex/auth.json ]; then
	scripts/hermes-import-codex-auth.sh
fi
docker compose ps

echo
echo "Hermes dashboard:    http://127.0.0.1:${HERMES_DASHBOARD_PORT:-19119}"
echo "Squid access log:    data/squid/logs/access.log"
echo "Codex callback:      http://127.0.0.1:${CODEX_LOGIN_CALLBACK_PORT:-1455}"

codex_status="$(scripts/codex-status.sh 2>/dev/null || true)"
codex_login_needed=false
if printf '%s\n' "$codex_status" | grep -q '^Logged in using ChatGPT'; then
	echo "Codex auth:          logged in"
else
	codex_login_needed=true
	echo "Codex auth:          not logged in"
fi

if [ "$run_setup" = true ]; then
	echo
	echo "Starting Hermes setup wizard..."
	docker compose run --rm hermes setup
fi

if [ "$codex_login_needed" = true ]; then
	if [ -t 0 ] && [ -t 1 ]; then
		echo
		echo "Starting Codex login because this is an interactive terminal."
		scripts/codex-login.sh
	else
		echo
		echo "Run this to log in with the browser callback flow:"
		echo "  scripts/codex-login.sh"
	fi
fi
