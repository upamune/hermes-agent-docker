# Hermes Agent Docker セットアップ

Hermes Agent を Docker 上で動かし、egress（外部通信）を g0efilter で制御するためのセットアップです。永続データはすべてこのリポジトリの `./data/` 以下に置きます（`$HOME/.hermes` は使いません）。

## ディレクトリ構成

| パス | 内容 |
| --- | --- |
| `data/hermes/` | Hermes の state（`./data/` は `.gitignore` / `.dockerignore` で除外） |
| `data/codex/` | Codex CLI の auth cache（Hermes state とは別 mount） |
| `data/g0efilter-policy/policy.yaml` | g0efilter の egress allowlist |
| `data/g0efilter-logs/` | g0efilter の audit log |
| `templates/hermes-config.yaml` | Hermes の初期 config（model / tools などの初期設定） |
| `templates/g0efilter-policy.yaml` | g0efilter の初期 policy |

初回（fresh）起動時に、`templates/` の内容が `data/` 配下にコピーされます。

- `templates/hermes-config.yaml` → `data/hermes/config.yaml`
- `templates/g0efilter-policy.yaml` → `data/g0efilter-policy/policy.yaml`

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
| g0efilter | `http://127.0.0.1:18081` |

Docker の port publish は `127.0.0.1` 限定です。同じ macOS からのみアクセスできます。

### Portless で開く

port 番号の代わりに安定した `.localhost` 名で開けます。

```sh
docker compose up -d

# g0efilter dashboard → http://hermes-egress.localhost:1355
portless hermes-egress sh -c 'npx --yes http-proxy-cli --port "$PORT" 127.0.0.1:18081'

# Hermes dashboard → http://hermes-dashboard.localhost:1355
portless hermes-dashboard sh -c 'npx --yes http-proxy-cli --port "$PORT" 127.0.0.1:19119'
```

## Egress 制御

Hermes は g0efilter の network namespace を共有しています。

```yaml
network_mode: "service:g0efilter"
```

このため、アプリ側の proxy 設定に依存せず、Hermes からの egress はすべて g0efilter を通ります。g0efilter は HTTP Host と TLS SNI を見て制御し、TLS の復号はしません。default deny で運用でき、ブロックした通信は dashboard に表示されます。

allowlist はホスト側の `data/g0efilter-policy/policy.yaml` で管理します。

```yaml
allowlist:
  ips:
    - "127.0.0.0/8"
    - "10.0.0.0/8"
    - "172.16.0.0/12"
    - "192.168.0.0/16"
  domains:
    - "*.chatgpt.com"
    - "*.openai.com"
    - "chatgpt.com"
    - "openai.com"
    - "*.anthropic.com"
```

一時的に全許可にする場合:

```yaml
allowlist:
  ips:
    - "0.0.0.0/0"
    - "::/0"
  domains: []
```

> `0.0.0.0/0` を入れるときは、`10.0.0.0/8` などの内側の CIDR と同時に入れないでください。nftables が重複 interval として弾きます。

policy mount は read-only で、remote unblock も無効化しています。container 側から `policy.yaml` を書き換えることはできません。許可を追加するときは必ずホスト側で編集します。

## Codex CLI ログイン

Compose は `hermes-agent-codex:latest` という派生 image を build し、その中で公式 installer を使って Codex CLI を入れています（`Dockerfile.hermes-codex`）。

```dockerfile
RUN curl -fsSL https://chatgpt.com/codex/install.sh | sh
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
```

macOS 側でログイン済みの auth cache を Hermes にコピーする場合:

```sh
codex login
scripts/codex-copy-host-auth.sh
```

Codex の認証キャッシュの保存先:

- ホスト: `data/codex/auth.json`
- container: `/opt/data/home/.codex/auth.json`

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

## 開発用コマンド

shell script の lint / format は mise で管理しています。

```sh
mise install
mise run format-shell
mise run lint-shell
```

## ネットワーク構成

### Hermes dashboard の proxy

Hermes dashboard 自体は、共有 network namespace 内の `127.0.0.1:9118` にだけ bind します。`hermes-dashboard-proxy` が同じ namespace 内で `:9119` を listen し、`127.0.0.1:9118` に reverse proxy します。Docker はそれを macOS の `127.0.0.1:19119` にだけ publish します。

外部公開しない前提のため、Hermes dashboard に Basic Auth はかけていません。

### Codex login callback の proxy

Codex の ChatGPT login は localhost callback port `1455` を使い、Codex CLI は container 内の `127.0.0.1:1455` に callback server を bind します。Docker の port publish は container の外向き interface に入るため、そのままでは macOS のブラウザから届きません。このため `codex-login-proxy` が container 外向き interface `:1455` から `127.0.0.1:1455` へ転送します。

```text
127.0.0.1:1455 (macOS) -> container :1455 -> 127.0.0.1:1455 (callback server)
```

### 書き込み可能な mount

g0efilter 系の container は read-only root filesystem で動かしています。container から書けるホスト側 directory は最小限です。

| ホスト | container | アクセス | 内容 |
| --- | --- | --- | --- |
| `./data/hermes` | `/opt/data` | rw | Hermes state |
| `./data/codex` | `/opt/data/home/.codex` | rw | Codex CLI auth cache |
| `./data/g0efilter-logs` | `/app/logs` | rw | g0efilter audit log |
| `./data/g0efilter-policy` | `/app/policy` | ro | g0efilter policy |

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
