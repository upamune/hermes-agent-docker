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

mkdir -p data/hermes/home/.codex data/g0efilter-logs data/g0efilter-policy

if [ ! -f data/hermes/config.yaml ] && [ -f templates/hermes-config.yaml ]; then
	cp templates/hermes-config.yaml data/hermes/config.yaml
	echo "created data/hermes/config.yaml from templates/hermes-config.yaml"
fi

if [ "$skip_setup" = false ] && [ "$force_setup" = false ] && [ ! -f data/hermes/config.yaml ]; then
	run_setup=true
fi

if [ ! -f data/g0efilter-policy/policy.yaml ] && [ -f templates/g0efilter-policy.yaml ]; then
	cp templates/g0efilter-policy.yaml data/g0efilter-policy/policy.yaml
	echo "created data/g0efilter-policy/policy.yaml from templates/g0efilter-policy.yaml"
elif [ ! -f data/g0efilter-policy/policy.yaml ]; then
	cat >data/g0efilter-policy/policy.yaml <<'EOF'
allowlist:
  ips:
    - "127.0.0.0/8"
    - "10.0.0.0/8"
    - "172.16.0.0/12"
    - "192.168.0.0/16"
  domains:
    - "*.openai.com"
    - "*.chatgpt.com"
    - "openai.com"
    - "chatgpt.com"
EOF
	echo "created data/g0efilter-policy/policy.yaml"
fi

if [ ! -f .env ]; then
	cp .env.example .env
	echo "created .env from .env.example"
fi

docker compose build hermes
docker compose up -d
docker compose stop codex-login-proxy >/dev/null 2>&1 || true
docker compose ps

echo
echo "Hermes dashboard:    http://127.0.0.1:${HERMES_DASHBOARD_PORT:-19119}"
echo "g0efilter dashboard: http://127.0.0.1:${G0EFILTER_DASHBOARD_PORT:-18081}"
echo "Codex callback:      http://127.0.0.1:${CODEX_LOGIN_CALLBACK_PORT:-1455}"

codex_status="$(scripts/codex-status.sh 2>/dev/null || true)"
if printf '%s\n' "$codex_status" | grep -q '^Logged in using ChatGPT'; then
	echo "Codex auth:          logged in"
else
	echo "Codex auth:          not logged in"
	echo
	echo "Run this to log in with the browser callback flow:"
	echo "  scripts/codex-login.sh"
fi

if [ "$run_setup" = true ]; then
	echo
	echo "Starting Hermes setup wizard..."
	docker compose run --rm hermes setup
fi
