#!/bin/sh

set -eu

cd "$(dirname "$0")/.."

scripts/render-squid-config.sh
docker compose up -d hermes >/dev/null
docker cp scripts/hermes-import-codex-auth.py hermes:/tmp/hermes-import-codex-auth.py
docker exec hermes sh -lc 'HOME=/opt/data/home CODEX_HOME=/opt/data/home/.codex /opt/hermes/.venv/bin/python /tmp/hermes-import-codex-auth.py'
echo "Restarting Hermes gateway to reload imported Codex credentials..."
docker exec hermes hermes gateway restart
echo "Hermes gateway restarted."
