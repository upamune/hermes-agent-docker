#!/bin/sh

set -eu

cd "$(dirname "$0")/.."

docker compose up -d hermes >/dev/null
docker cp scripts/hermes-import-codex-auth.py hermes:/tmp/hermes-import-codex-auth.py
docker exec hermes sh -lc 'HOME=/opt/data/home CODEX_HOME=/opt/data/home/.codex /opt/hermes/.venv/bin/python /tmp/hermes-import-codex-auth.py'
