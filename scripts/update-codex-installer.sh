#!/bin/sh

set -eu

cd "$(dirname "$0")/.."

url="${CODEX_INSTALLER_URL:-https://chatgpt.com/codex/install.sh}"
target="vendor/codex/install.sh"
tmp="$(mktemp)"

cleanup() {
	rm -f "$tmp"
}
trap cleanup EXIT INT TERM

curl -fsSL "$url" -o "$tmp"
sh -n "$tmp"

mkdir -p "$(dirname "$target")"
install -m 0644 "$tmp" "$target"

echo "updated $target from $url"
