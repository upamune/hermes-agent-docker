#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

mkdir -p data/squid/conf.d/repo data/squid/conf.d/user data/squid/logs
cp templates/squid.conf data/squid/squid.conf
cp templates/squid.repo.conf data/squid/conf.d/repo/repo.conf

if [ -f templates/squid.user.conf ]; then
	cp templates/squid.user.conf data/squid/conf.d/user/user.conf
else
	: >data/squid/conf.d/user/user.conf
fi

squid_container="$(docker compose ps --status running -q squid 2>/dev/null || true)"
if [ -n "$squid_container" ]; then
	echo "Restarting Squid to reload generated egress rules..."
	docker compose restart squid
fi
