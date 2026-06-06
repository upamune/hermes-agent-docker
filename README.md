# Hermes Agent Docker セットアップ

このディレクトリを Hermes Agent の永続データ置き場として使います。`$HOME/.hermes` は使いません。

- Hermes データ: `./data/hermes`
- g0efilter ポリシー: `./data/g0efilter-policy/policy.yaml`
- g0efilter ログ: `./data/g0efilter-logs/`
- Hermes 初期 config template: `./templates/hermes-config.yaml`
- g0efilter 初期 policy template: `./templates/g0efilter-policy.yaml`

runtime に生成される mount 先はすべて `./data/` 以下に集約しています。`data/` は `.gitignore` と `.dockerignore` で除外しています。

## 起動

clone 後に最初にやること:

```sh
scripts/hermes-up.sh
scripts/codex-ensure-login.sh
```

`scripts/hermes-up.sh` は Docker image を build して Compose services を起動します。fresh 環境では `templates/` から `data/` に初期設定をコピーします。

`scripts/codex-ensure-login.sh` は Codex の login status を確認し、未ログインなら browser callback login を開始します。

fresh 起動時には template から runtime data が作られます。

- `templates/hermes-config.yaml` -> `data/hermes/config.yaml`
- `templates/g0efilter-policy.yaml` -> `data/g0efilter-policy/policy.yaml`

template には model / tools / egress allowlist などの初期設定を入れます。

`scripts/hermes-up.sh` は Codex の login status も確認します。未ログインなら、次に実行するコマンドとして `scripts/codex-login.sh` を表示します。

Hermes setup wizard を強制的に実行したい場合:

```sh
scripts/hermes-up.sh --setup
```

fresh 検証などで setup wizard を起動したくない場合:

```sh
scripts/hermes-up.sh --no-setup
```

## アクセス先

Hermes dashboard:

```text
http://127.0.0.1:19119
```

g0efilter dashboard:

```text
http://127.0.0.1:18081
```

どちらも Docker の port publish は `127.0.0.1` 限定です。同じ macOS からだけアクセスできます。

## Egress 制御

Hermes は g0efilter の network namespace を共有しています。

```yaml
network_mode: "service:g0efilter"
```

そのため、アプリケーション側の proxy 設定に依存せず、Hermes からの egress は g0efilter に捕まります。g0efilter は HTTP Host と TLS SNI を見て制御します。TLS の復号はしません。

g0efilter は default deny で使えます。ブロックされた通信は dashboard に表示されます。

allowlist はホスト側のこのファイルで管理します。

```text
data/g0efilter-policy/policy.yaml
```

例:

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

`0.0.0.0/0` を入れる場合は、`10.0.0.0/8` などの内側の CIDR と同時に入れないでください。nftables が重複 interval として弾きます。

remote unblock は無効化しています。container から `data/g0efilter-policy` を書き換えられないように、policy mount は read-only です。許可追加は必ずホスト側で `policy.yaml` を編集します。

## Portless

portless を使うと、localhost の port 番号ではなく安定した `.localhost` 名で開けます。

g0efilter dashboard:

```sh
docker compose up -d
portless hermes-egress sh -c 'npx --yes http-proxy-cli --port "$PORT" 127.0.0.1:18081'
```

開く URL:

```text
http://hermes-egress.localhost:1355
```

Hermes dashboard:

```sh
portless hermes-dashboard sh -c 'npx --yes http-proxy-cli --port "$PORT" 127.0.0.1:19119'
```

開く URL:

```text
http://hermes-dashboard.localhost:1355
```

## Hermes Dashboard

Hermes dashboard 自体は、shared container network namespace 内の `127.0.0.1:9118` にだけ bind します。

`hermes-dashboard-proxy` が同じ namespace 内で `:9119` を listen し、`127.0.0.1:9118` に reverse proxy します。Docker はそれを macOS の `127.0.0.1:19119` にだけ publish します。

この構成では Hermes dashboard に Basic Auth はかけていません。外部公開はしていない前提です。

## Codex CLI

この Compose は `hermes-agent-codex:latest` という派生イメージを build します。中で公式 installer を使って Codex CLI を入れています。

```dockerfile
RUN curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Codex の ChatGPT login は localhost callback port `1455` を使います。この Compose では macOS localhost に publish しています。

```text
127.0.0.1:1455 -> container :1455
```

Codex CLI は container 内の `127.0.0.1:1455` に callback server を bind します。Docker の port publish は container の外向き interface に入るため、そのままだと macOS のブラウザから届きません。このため `codex-login-proxy` が container 外向き interface `:1455` から `127.0.0.1:1455` へ転送します。

ブラウザで `ERR_EMPTY_RESPONSE` が出る場合は、古い login process と proxy を作り直してから再実行します。

```sh
docker exec hermes sh -lc 'pkill -f "[c]odex login" || true'
docker compose up -d codex-login-proxy
scripts/codex-login.sh
```

Codex login:

```sh
scripts/codex-login.sh
```

このコマンドは OpenAI auth URL を terminal に表示して待機します。表示された URL を macOS のブラウザで開いてください。`--device-auth` は使いません。ChatGPT Enterprise で device code auth が拒否されている場合でも、通常の callback flow を使えます。

`codex-login-proxy` は login 中だけ使います。`scripts/codex-login.sh` が終了または中断されると、この container だけ自動で停止します。手動で止める場合:

```sh
docker compose stop codex-login-proxy
```

Codex status:

```sh
scripts/codex-status.sh
```

未ログインならそのまま login flow を開始する場合:

```sh
scripts/codex-ensure-login.sh
```

macOS 側でログイン済みの Codex auth cache を Hermes にコピーする場合:

```sh
codex login
scripts/codex-copy-host-auth.sh
```

Codex の認証キャッシュはここに保存されます。

```text
data/hermes/home/.codex/auth.json
```

container 側では以下として見えます。

```text
/opt/data/home/.codex/auth.json
```

`.dockerignore` で `data/hermes/` を build context から除外しています。これは `auth.json` を Docker image build に混ぜないためです。実行時は bind mount されるので、Hermes container からは読めます。

## スクリプト一覧

```text
scripts/hermes-up.sh
```

Hermes image を build して、Compose services を起動します。
`data/hermes/config.yaml` が無ければ Hermes setup wizard も自動で実行します。
ただし `templates/hermes-config.yaml` がある場合は先にそれをコピーするため、通常は template ベースで起動します。

```text
scripts/codex-login.sh
```

Hermes container 内で Codex の ChatGPT callback login を開始します。

```text
scripts/codex-status.sh
```

Hermes container 内の Codex CLI version と login status を確認します。

```text
scripts/codex-ensure-login.sh
```

Codex の login status を確認し、未ログインなら `scripts/codex-login.sh` を起動します。

```text
scripts/codex-copy-host-auth.sh
```

macOS の `~/.codex/auth.json` を `data/hermes/home/.codex/auth.json` にコピーします。

## 書き込み可能な mount

g0efilter 系 container は read-only root filesystem で動かしています。

container から書ける host directory は最小限です。

- `./data/hermes` -> `/opt/data`: Hermes state
- `./data/g0efilter-logs` -> `/app/logs`: g0efilter audit logs

`./data/g0efilter-policy` -> `/app/policy` は read-only です。

## Docker Image Pinning

Docker image は Renovate で digest pinning する前提です。

```text
renovate.json
```

Renovate は以下を対象にします。

- `Dockerfile.hermes-codex` の `FROM nousresearch/hermes-agent:...`
- `docker-compose.yml` の外部 image

`hermes-agent-codex:latest` はローカル build image なので Renovate 対象外です。

Renovate は新しい release/digest が出ても 7 日間は PR を作らない設定です。

```json
"minimumReleaseAge": "7 days",
"internalChecksFilter": "strict"
```

ローカルで最新 tag を明示的に取りに行く場合:

```sh
docker compose pull
docker compose build --pull hermes
scripts/hermes-up.sh
```

digest pin 済みの運用では、通常は Renovate の PR を取り込んでから `scripts/hermes-up.sh` を実行します。
