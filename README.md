# Hermes Agent Docker セットアップ

Hermes Agent を Docker 上で動かし、egress（外部通信）を Squid proxy と internal Docker network で制御するためのセットアップです。永続データはすべてこのリポジトリの `./data/` 以下に置きます（`$HOME/.hermes` は使いません）。

## ディレクトリ構成

| パス | 内容 |
| --- | --- |
| `data/hermes/` | Hermes の state（`./data/` は `.gitignore` / `.dockerignore` で除外） |
| `data/codex/` | Codex CLI の auth cache（Hermes state とは別 mount） |
| `data/squid/squid.conf` | 生成済み Squid config |
| `data/squid/conf.d/` | repo 定義 rule と user 定義 rule |
| `data/squid/logs/` | Squid access/cache logs |
| `templates/hermes-config.yaml` | Hermes の初期 config（model / tools などの初期設定） |
| `templates/hermes-config-mcp.yaml.example` | MCP 設定用のサンプル。編集用の `templates/hermes-config-mcp.yaml` は git ignore |
| `templates/squid.repo.conf` | repo 定義の Squid allowlist |
| `templates/squid.user.conf.example` | user 定義 Squid rule のサンプル。編集用の `templates/squid.user.conf` は git ignore |

初回（fresh）起動時に、`templates/` の内容が `data/` 配下にコピーされます。

- `templates/hermes-config.yaml` → `data/hermes/config.yaml`
- `templates/squid.conf` + `templates/squid.repo.conf` + `templates/squid.user.conf` → `data/squid/`

MCP 設定を分けて管理したい場合は、ignored の編集用ファイルを使います。

```sh
cp templates/hermes-config-mcp.yaml.example templates/hermes-config-mcp.yaml
```

`templates/hermes-config-mcp.yaml` が存在する場合だけ、fresh 起動時に `scripts/hermes-up.sh` が `templates/hermes-config.yaml` へ YAML merge して `data/hermes/config.yaml` を生成します。既存の `data/hermes/config.yaml` は上書きしません。

## クイックスタート

clone 後にまず実行します。

```sh
scripts/hermes-up.sh
scripts/codex-ensure-login.sh
```

- `scripts/hermes-up.sh` — Docker image を build し、Compose services を起動します。fresh 環境では `templates/` から `data/` に初期設定をコピーします。
- `scripts/codex-ensure-login.sh` — Codex の login status を確認し、未ログインなら login flow を開始します。

Hermes の setup wizard を制御するオプションもあります。

```sh
scripts/hermes-up.sh --setup     # setup wizard を強制実行する
scripts/hermes-up.sh --no-setup  # fresh 検証などで setup wizard を起動しない
```

## アクセス先

| Dashboard | URL |
| --- | --- |
| Hermes | `http://127.0.0.1:19119` |

Docker の port publish は `127.0.0.1` 限定です。同じ macOS からのみアクセスできます。

### Portless で開く

port 番号の代わりに安定した `.localhost` 名で開けます。

```sh
docker compose up -d

# Hermes dashboard → http://hermes-dashboard.localhost:1355
portless hermes-dashboard sh -c 'npx --yes http-proxy-cli --port "$PORT" 127.0.0.1:19119'
```

## Egress 制御

Hermes は internal Docker network のみに接続されます。外へ出られる container は Squid だけです。

```yaml
networks:
  hermes-internal:
    internal: true
```

Hermes には `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` として `http://squid:3128` を渡します。proxy を無視する direct egress は internal network で外へ出られません。

repo 定義 rule は `templates/squid.repo.conf`、ユーザー定義 rule は ignored の `templates/squid.user.conf` に分けます。起動時に `scripts/render-squid-config.sh` が `data/squid/` に生成します。

```conf
# templates/squid.repo.conf
acl repo_web_ports port 80 443
acl repo_openai_domains dstdomain .openai.com .chatgpt.com
http_access allow repo_openai_domains repo_web_ports
```

ユーザー固有の host/port 許可を足す場合:

```sh
cp templates/squid.user.conf.example templates/squid.user.conf
```

```conf
# templates/squid.user.conf
acl yourapp_host dstdomain host.docker.internal
acl yourapp_port port 8080
http_access allow yourapp_host yourapp_port
```

Squid は `host:port` で `CONNECT` を制御できるので、`host.docker.internal` 全体ではなく `host.docker.internal:3999` のように port 単位で許可できます。block/allow は `data/squid/logs/access.log` で確認します。

## Codex CLI ログイン

Compose は `hermes-agent-codex:latest` という派生 image を build し、その中で公式 installer を使って Codex CLI を入れています（`Dockerfile.hermes-codex`）。

```dockerfile
COPY vendor/codex/install.sh /tmp/codex-install.sh
RUN sh /tmp/codex-install.sh
```

Docker build 時に installer をネットワークから取得しないよう、`vendor/codex/install.sh` をリポジトリに固定しています。installer を更新する場合:

```sh
mise run update-codex-installer
```

### 通常のログイン

```sh
scripts/codex-login.sh
```

OpenAI の auth URL が terminal に表示され、待機状態になります。表示された URL を macOS のブラウザで開いてください。`--device-auth` は使いません。ChatGPT Enterprise で device code auth が拒否されている環境でも、通常の callback flow を使えます。

`codex-login-proxy` は login 中だけ使います。`scripts/codex-login.sh` が終了・中断されると、この container だけ自動で停止します。手動で止める場合:

```sh
docker compose stop codex-login-proxy
```

ブラウザで `ERR_EMPTY_RESPONSE` が出る場合は、古い login process と proxy を作り直してから再実行します。

```sh
docker exec hermes sh -lc 'pkill -f "[c]odex login" || true'
docker compose up -d codex-login-proxy
scripts/codex-login.sh
```

### その他の操作

```sh
scripts/codex-status.sh        # version と login status を確認
scripts/codex-ensure-login.sh  # 未ログインならそのまま login flow を開始
scripts/hermes-import-codex-auth.sh  # Codex CLI auth cache を Hermes auth store に同期
```

macOS 側でログイン済みの auth cache を Hermes にコピーする場合:

```sh
codex login
scripts/codex-copy-host-auth.sh
```

Codex の認証キャッシュの保存先:

- ホスト: `data/codex/auth.json`
- container: `/opt/data/home/.codex/auth.json`

Hermes の `openai-codex` provider は Codex CLI の `auth.json` を直接は読みません。`scripts/hermes-up.sh` は `data/codex/auth.json` が存在する場合に自動で `scripts/hermes-import-codex-auth.sh` を実行し、Codex CLI の token を Hermes の auth store に同期します。`scripts/codex-login.sh` と `scripts/codex-copy-host-auth.sh` も最後に同じ同期を実行します。同期後は gateway を restart して、更新された auth store を読み直します。手動で再同期する場合も同じスクリプトを実行してください。

`data/codex/` は `data/hermes/` とは別の bind mount として `/opt/data/home/.codex` に重ねています。Hermes の通常 state と Codex 認証キャッシュをホスト側で分離し、directory permission は scripts 側で `install -d -m 700` に寄せます。

`.dockerignore` で `data/` を build context から除外しているため、`auth.json` が Docker image build に混ざることはありません。実行時は bind mount されるので、Hermes container からは読めます。

## スクリプト一覧

| スクリプト | 内容 |
| --- | --- |
| `scripts/hermes-up.sh` | Hermes image を build して Compose services を起動。`data/hermes/config.yaml` が無ければ setup wizard を自動実行（通常は `templates/` を先にコピーするため template ベースで起動） |
| `scripts/codex-login.sh` | Hermes container 内で Codex の ChatGPT callback login を開始 |
| `scripts/codex-status.sh` | container 内の Codex CLI version と login status を確認 |
| `scripts/codex-ensure-login.sh` | login status を確認し、未ログインなら `codex-login.sh` を起動 |
| `scripts/codex-copy-host-auth.sh` | macOS の `~/.codex/auth.json` を `data/codex/auth.json` にコピー |
| `scripts/hermes-import-codex-auth.sh` | `scripts/hermes-import-codex-auth.py` を container にコピーして、`data/codex/auth.json` を Hermes の `openai-codex` auth store に同期 |

## 開発用コマンド

shell script の lint / format は mise で管理しています。

```sh
mise install
mise run format-shell
mise run lint-shell
mise run lint-docker
mise exec -- pinact run --check --verify-comment
```

pre-commit hook を有効化する場合:

```sh
mise run install-hooks
```

## ネットワーク構成

### Hermes dashboard の proxy

Hermes dashboard 自体は、共有 network namespace 内の `127.0.0.1:9118` にだけ bind します。`hermes-dashboard-proxy` が同じ namespace 内で `:9119` を listen し、`127.0.0.1:9118` に reverse proxy します。`hermes-ingress` が macOS の `127.0.0.1:19119` にだけ publish します。

外部公開しない前提のため、Hermes dashboard に Basic Auth はかけていません。

### Codex login callback の proxy

Codex の ChatGPT login は localhost callback port `1455` を使い、Codex CLI は container 内の `127.0.0.1:1455` に callback server を bind します。Docker の port publish は container の外向き interface に入るため、そのままでは macOS のブラウザから届きません。このため `codex-login-proxy` が container 外向き interface `:1455` から `127.0.0.1:1455` へ転送し、`hermes-ingress` が macOS の `127.0.0.1:1455` に publish します。

```text
127.0.0.1:1455 (macOS) -> hermes-ingress -> hermes :1455 -> 127.0.0.1:1455 (callback server)
```

### 書き込み可能な mount

container から書けるホスト側 directory は最小限です。

| ホスト | container | アクセス | 内容 |
| --- | --- | --- | --- |
| `./data/hermes` | `/opt/data` | rw | Hermes state |
| `./data/codex` | `/opt/data/home/.codex` | rw | Codex CLI auth cache |
| `./data/squid/squid.conf` | `/etc/squid/squid.conf` | ro | Squid generated config |
| `./data/squid/conf.d` | `/etc/squid/conf.d` | ro | Squid generated rules |
| `./data/squid/logs` | `/var/log/squid` | rw | Squid logs |

## Docker image の pinning

Docker image は Renovate で digest pinning する前提です（`renovate.json`）。

Renovate の対象:

- `Dockerfile.hermes-codex` の `FROM nousresearch/hermes-agent:...`
- `docker-compose.yml` の外部 image

ローカル build image の `hermes-agent-codex:latest` は対象外です。新しい release/digest が出ても 7 日間は PR を作らない設定です。

```json
"minimumReleaseAge": "7 days",
"internalChecksFilter": "strict"
```

通常は Renovate の PR を取り込んでから `scripts/hermes-up.sh` を実行します。ローカルで最新 tag を明示的に取りに行く場合:

```sh
docker compose pull
docker compose build --pull hermes
scripts/hermes-up.sh
```
