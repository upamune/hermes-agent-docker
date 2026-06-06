# Repository Guidelines

## Project Structure & Module Organization

This repository defines a Docker-based Hermes Agent setup with Codex CLI support and g0efilter egress control.

- `docker-compose.yml`: service definitions for Hermes, g0efilter, dashboards, and Codex login proxy.
- `Dockerfile.hermes-codex`: derived Hermes image that installs Codex CLI.
- `scripts/`: operational shell scripts for startup, Codex login, and status checks.
- `templates/`: public initial configuration copied into runtime data on first startup.
- `data/`: local runtime state, credentials, logs, and generated config. This directory is ignored and must not be committed.

There is no application source tree or test suite beyond Compose/scripts validation.

## Build, Test, and Development Commands

```sh
scripts/hermes-up.sh
```
Builds the Hermes image, starts services, creates runtime config from templates if missing, and prints access URLs.

```sh
scripts/hermes-up.sh --setup
```
Forces the Hermes setup wizard.

```sh
scripts/codex-ensure-login.sh
```
Checks Codex login status and starts callback login if needed.

```sh
docker compose config
```
Validates Compose syntax and interpolated configuration.

```sh
for f in scripts/*.sh; do sh -n "$f"; done
```
Checks shell script syntax.

## Coding Style & Naming Conventions

Use POSIX-compatible `sh` for scripts unless a stronger shell is required. Keep scripts small, explicit, and idempotent. Prefer lowercase kebab-case filenames, for example `codex-login.sh`. Use two-space indentation for YAML. Keep template files free of machine-specific paths and secrets.

## Testing Guidelines

Before submitting changes, run:

```sh
docker compose config
for f in scripts/*.sh; do sh -n "$f"; done
```

For behavior changes, test a fresh runtime by removing or moving `data/`, then running `scripts/hermes-up.sh --no-setup`. Verify both dashboards respond on `127.0.0.1:19119` and `127.0.0.1:18081`.

## Commit & Pull Request Guidelines

This repository has no established Git history yet. Use concise imperative commits such as `Add Codex login proxy` or `Move runtime state under data`. Pull requests should describe the operational change, list commands run, and call out any security or networking impact.

## Security & Configuration Tips

Never commit `.env`, `data/`, `auth.json`, logs, or backups. Runtime state belongs under `data/` only. Public defaults live in `templates/`. g0efilter policy is mounted read-only into the container, so allowlist changes should be made on the host-side template or generated runtime file intentionally.
