import json
from pathlib import Path

from hermes_cli.auth import _save_codex_tokens


def main() -> None:
    auth_path = Path("/opt/data/home/.codex/auth.json")
    if not auth_path.is_file():
        raise SystemExit("missing /opt/data/home/.codex/auth.json; run scripts/codex-login.sh first")

    payload = json.loads(auth_path.read_text())
    tokens = payload.get("tokens")
    if not isinstance(tokens, dict):
        raise SystemExit("Codex auth.json is missing tokens")

    access_token = tokens.get("access_token")
    refresh_token = tokens.get("refresh_token")
    if not isinstance(access_token, str) or not access_token.strip():
        raise SystemExit("Codex auth.json is missing access_token")
    if not isinstance(refresh_token, str) or not refresh_token.strip():
        raise SystemExit("Codex auth.json is missing refresh_token")

    last_refresh = payload.get("last_refresh")
    if not isinstance(last_refresh, str) or not last_refresh.strip():
        last_refresh = None

    _save_codex_tokens(tokens, last_refresh=last_refresh, label="codex-cli")
    print("imported Codex CLI credentials into Hermes auth store")


if __name__ == "__main__":
    main()
