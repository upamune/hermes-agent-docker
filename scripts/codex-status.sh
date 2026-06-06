#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

rm -rf data/hermes/home/.codex/tmp/arg0
docker exec hermes sh -lc 'rm -rf /opt/data/home/.codex/tmp/arg0 /root/.codex/tmp/arg0 2>/dev/null || true'

docker exec hermes sh -lc 'HOME=/opt/data/home CODEX_HOME=/opt/data/home/.codex codex --version 2>&1' \
  | sed '/^WARNING: failed to clean up stale arg0 temp dirs:/d; /^WARNING: proceeding, even though we could not update PATH:/d'

rm -rf data/hermes/home/.codex/tmp/arg0
docker exec hermes sh -lc 'rm -rf /opt/data/home/.codex/tmp/arg0 /root/.codex/tmp/arg0 2>/dev/null || true'

docker exec hermes sh -lc 'HOME=/opt/data/home CODEX_HOME=/opt/data/home/.codex codex login status 2>&1' \
  | sed '/^WARNING: failed to clean up stale arg0 temp dirs:/d; /^WARNING: proceeding, even though we could not update PATH:/d'

rm -rf data/hermes/home/.codex/tmp/arg0
