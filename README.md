# CoolifyGo ✨

A pure mini reimplementation of [Coolify's v3 Branch](https://github.com/coollabsio/coolify) in Go — a self-hosted PaaS for deploying applications, databases, and services via Docker and SSH.

## Code Stats:
[![DeepSource](https://app.deepsource.com/gh/annihilatorrrr/coolifygo.svg/?label=active+issues&show_trend=true&token=ymMYtFVTG4J5NzFqTkiqzwUZ)](https://app.deepsource.com/gh/annihilatorrrr/coolifygo/)

## Note:
> This repo is just made for actions like Bug reports, Issues, Feature requests, Update, Install, Unimstall only; Codebase is kept private because of heavy commit spam/ unwanted or unseen security bugs, if you find one you can raise a issue to get it fixed. Don't worry there is no such virus/ malware in the codebase/ binary test it before using !

**Single binary. No Node. No PHP. No Laravel. Just Go.**

[![Go](https://img.shields.io/badge/Go-1.26-00ADD8?logo=go)](https://go.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-SDK%20v28-2496ED?logo=docker)](https://docs.docker.com/engine/api/)
[![ghcr.io](https://img.shields.io/badge/ghcr.io-coolifygo-blue?logo=github)](https://ghcr.io/annihilatorrrr/coolifygo)

---

## Table of Contents

- [Features](#features)
- [Quick Install](#quick-install)
- [Update](#update)
- [Uninstall](#uninstall)
- [Getting Started](#getting-started)
- [Forgot Password](#forgot-password)
- [Manual Setup](#manual-setup)
- [Environment Variables](#environment-variables)
- [One-Click Services](#one-click-services)
- [Auto-Deploy Webhooks](#auto-deploy-webhooks)
- [API](#api)
- [Tech Stack](#tech-stack)
- [Development](#development)
- [License](#license)

---

## Features

- **Applications** — deploy from any Git repo using Dockerfile or Docker Compose; access via `http://serverIP:port`
  - **Force Redeploy** — one-click rebuild that bypasses Docker's layer cache and re-pulls base images
  - **Healthcheck** — HTTP probe (path / port / interval) **or** custom shell CMD (`pg_isready`, `curl`, etc.); live `healthy / unhealthy / starting` badge in the UI action bar
  - **Webhook Signing** — per-app HMAC-SHA256 secret (GitHub `X-Hub-Signature-256`) or shared token (GitLab `X-Gitlab-Token`); every delivery logged in the Webhooks tab with signature status and result
  - **Build Secrets (Build Args)** — separate `build_args` from runtime `env_vars`; set in Secrets tab → Build sub-tab
  - **Push Registry** — optionally tag and push every successful build to a private registry (ghcr.io, Docker Hub, etc.)
  - **Cancel Build** — abort an in-flight deploy from the Build Logs tab or the dashboard's Active Deploys panel
  - **Full error logs** — on build failure the complete persisted log is loaded, not just the live tail
- **Managed Databases** — PostgreSQL, MySQL, MongoDB, Redis
  - **Root credentials** — separate `root_user` / `root_password` / `default_database` fields exposed as Docker env vars
  - **Auto port allocation** — when "Expose publicly" is toggled on, a free host port is auto-assigned from the configured range (Settings → Network & Ports, default 9000-9100). Port is read-only in the UI.
  - **Internal + external connection strings** — internal uses container hostname (for other apps on the coolify network); external shows server IP + public port (only when exposed)
  - **Scheduled backups → Telegram** — per-DB cron schedule; gzipped dump streamed to a Telegram chat as a file. Postgres uses `pg_dump -Fc -Z 9`. Telegram 50 MB pre-flight + 429 retry-after handled. Per-DB token/chat overrides win over system Settings.
- **One-Click Services** — 7 templates: Nextcloud, Redis Stack, Uptime Kuma, Grafana, Prometheus, Vaultwarden, Gitea — each detail page shows a quick-access panel with admin URLs and credentials
- **Port conflict check** — creating or editing an app port is rejected (409) if that port is already used by another app or database on the same server
- **TOFU SSH host-key verification** — server host keys are captured on first connect and verified on every subsequent dial (Trust On First Use); stored in `servers.host_key`
- **Update checker** — Settings → Updates checks the GHCR tag list for a newer version; "Update Now" pre-pulls the image; the dashboard banner shows the result (idle → checking → up-to-date → update-available)
- **Zero Server Setup** — local Docker server auto-created on first registration; wizards auto-skip destination when only one server exists
- **Single-User System** — registration blocked after first account
- **Real-time Logs** — live WebSocket streaming for app logs, build logs, DB logs, service logs
- **Active Deploys panel** — pinned to dashboard, live cancel buttons, 5 s refresh
- **API Tokens** — full REST API with bearer token auth; tokens also accepted as `?token=` query param for WebSocket connections
- **Telegram Notifications** — deploy success/fail, backup done/failed; via **Settings → Notifications** (no restart needed)
- **Git Sources** — token, SSH-key, and GitHub App manifest flow
- **Auto-Deploy** — Git push webhooks for GitHub, GitLab, Gitea, Bitbucket (with signature verification)
- **Extra Docker Args** — per-app raw `--memory`, `--cpus`, `--cap-add`, `--add-host`, sysctls, etc.
- **Docker Cleanup** — scheduled prune every 15 min; delete cleans up container + image + volume
- **v3-style Dashboard** — `+ Create New Resource` dropdown, Bots/Running/Stopped/Error filter pills, cyan Docker whale icon per app card, BOT badge
- **Mobile-friendly UI** — responsive across all screen sizes

---

## Quick Install

### Public install (no PAT)

```bash
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/install.sh | sudo bash
```

- Pulls the pre-built Docker image from `ghcr.io` — no Go install, no compilation, ~30 seconds
- Default port: `3000` — override with `COOLIFY_PORT=8080`
- Install directory: `/data/coolifygo` — override with `COOLIFY_DIR=/opt/coolifygo`
- Automatically installs Docker if not present
- Creates a systemd service (`coolifygo`) that starts on boot

After install, open `http://<server-ip>:3000` and register your first (and only) user.

**Reinstall:** Running the install script again performs a clean reinstall — stops the container, pulls the latest image, recreates the container. Your config, deployed containers, databases, and volumes are never touched.

### Supported platforms

The Docker image and binaries ship for both `linux/amd64` and `linux/arm64`. The install script auto-detects the architecture and pulls the right one.

| Platform | Architecture | Notes |
|---|---|---|
| Most VPS / bare metal | `amd64` | Default. ≥1 GB RAM recommended. |
| **Oracle Cloud Free Tier — Ampere A1** | `arm64` | Up to 4 OCPU / 24 GB RAM free forever. The best free target — open the dashboard port (3000) in the **VCN security list** and `firewall-cmd --add-port=3000/tcp --permanent`. |
| Oracle Cloud Free Tier — AMD micro | `amd64` | Tight at 1 GB RAM. Plan for 1 small app per VM, or split DB to a second VM. |
| **Raspberry Pi 5** | `arm64` | 64-bit Pi OS / Ubuntu Server required. 8 GB / 16 GB models comfortably run a handful of apps. |
| Apple Silicon Macs (dev only) | `arm64` | Use Docker Desktop; not intended for production. |

If you're on a fresh Oracle Linux / RHEL box, the installer's `get.docker.com` step covers both `apt` and `dnf` distros.

---

## Update

Pulls the latest image and recreates the container. Deployed containers keep running throughout. Most users won't need this — **Settings → Updates → Update Now** in the dashboard does the same swap from the UI.

```bash
# Image + apt packages
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/update.sh | sudo bash

# Skip apt
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/update.sh | sudo bash -s -- --skip-apt

# + Docker cleanup via API (needs COOLIFY_API_TOKEN)
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/update.sh | \
  sudo COOLIFY_API_TOKEN=cgo_... bash -s -- --cleanup-api
```

The previous image is tagged as `:bak` before pulling. To rollback:

```bash
docker stop coolifygo && docker rm coolifygo
docker run -d --name coolifygo --restart no \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /data/coolifygo:/data/coolifygo \
  -e COOLIFY_DATA_DIR=/data/coolifygo \
  -e COOLIFY_PORT=3000 \
  ghcr.io/annihilatorrrr/coolifygo:bak
systemctl restart coolifygo
```

---

## Uninstall

### Remove CoolifyGo, keep your containers running (recommended)

Removes the CoolifyGo container and systemd service. All deployed app containers, databases, and volumes **keep running** — identical to Coolify v3 removal behavior. Your data directory (`/data/coolifygo`) is preserved so you can reinstall and reconnect later.

```bash
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/uninstall.sh | sudo bash
```

### Remove everything (full wipe)

Stops and removes all managed containers (apps, databases, one-click services, internal Postgres/Redis) and deletes the data directory.

```bash
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/uninstall.sh | \
  sudo bash -s -- --full -y
```

### Remove everything including Docker

```bash
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/uninstall.sh | \
  sudo bash -s -- --full --purge-docker -y
```

---

## Getting Started

### 1. Register & Log In

Open `http://<server-ip>:3000`. Register the first (and only) account — this becomes the admin. **Registration is permanently disabled after the first user is created.** A local Docker server is automatically provisioned for you — no manual server setup is ever needed.

### 2. Deploy an Application

Go to **Applications → + New Application**. A 3-step wizard guides you through:

1. **Select Source** — Public Git URL, Dockerfile inline, or GitHub (coming soon)
2. **Build Pack** — choose Dockerfile or Docker Compose
3. **Configure** — set Name and Port

Click **Deploy**. Build logs stream live in the dashboard. Once running, the app is accessible at `http://<serverIP>:<port>`.

The auto-deploy toggle on each app card enables/disables webhook-triggered deploys per app.

**Extra Docker Args:** In the app's **Configuration** tab, the _Extra Docker Args_ field accepts raw docker run flags applied at deploy time:

```
--memory=512m --cpus=1.5 --cap-add=SYS_PTRACE --add-host=mydb:192.168.1.10
```

### 3. Deploy a Database

Go to **Databases → + New Database**, walk through the wizard (type → version → configure) and deploy. Connection strings are shown in the database detail panel.

### 4. Configure Telegram Notifications

Go to **Settings → Notifications**. Enter your Bot Token and Chat ID, hit **Save**, then **Send Test Message** to verify. Notifications use rich HTML formatting with emoji, commit hash, deploy duration, app URL, and failure reason.

---

## Forgot Password

If you're locked out, trigger a password reset from the login page. The new password is written to:

```
/data/coolifygo/coolifygo-password.txt
```

Read it on your server:

```bash
cat /data/coolifygo/coolifygo-password.txt
```

The file is always overwritten — no duplicates accumulate. After logging in, change your password via **Settings → Profile**.

---

## Manual Setup

### Requirements

- Linux (x86_64 or arm64)
- Docker ≥ 24 with Compose v2 (`docker compose version`)

> PostgreSQL and Redis are **not** required upfront — CoolifyGo self-bootstraps them as Docker containers on first run.

### Run via Docker (recommended)

```bash
docker pull ghcr.io/annihilatorrrr/coolifygo:latest

docker run -d \
  --name coolifygo \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /data/coolifygo:/data/coolifygo \
  -e COOLIFY_DATA_DIR=/data/coolifygo \
  -e COOLIFY_PORT=3000 \
  ghcr.io/annihilatorrrr/coolifygo:latest
```

### Build & Run from Source

```bash
cp .env.example .env
# edit .env — fill in DATABASE_URL, JWT_SECRET, REDIS_URL

docker compose -f docker/docker-compose.yml up -d   # Postgres + Redis
go build -o bin/coolifygo ./cmd/server
./bin/coolifygo                                       # default port 3000
./bin/coolifygo -port 8080                            # custom port
```

### Build Docker Image locally

```bash
docker build -f docker/Dockerfile -t coolifygo:latest .
```

Two-stage build (`golang:1.26-alpine` → `scratch`). Final image is ~25 MB with no shell, no package manager, no attack surface. Uses Go cross-compilation for fast multi-arch builds (amd64 + arm64).

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | — | PostgreSQL DSN, e.g. `postgres://user:pass@host:5432/db?sslmode=disable` |
| `JWT_SECRET` | — | Secret for signing JWTs — use at least 32 random chars |
| `REDIS_URL` | `redis://localhost:6379` | Redis for the async job queue |
| `APP_ENV` | `development` | Set to `production` for JSON logging |
| `SERVER_PORT` | `3000` | HTTP listen port (also overridable via `-port` flag) |
| `JWT_EXPIRY_HOURS` | `72` | Token lifetime in hours |
| `DOCKER_CLEANUP_THRESHOLD` | `80` | Disk usage % that lights up the cleanup warning badge |
| `COOLIFY_DATA_DIR` | `/data/coolifygo` | Data directory — must match the volume mount path |
| `TELEGRAM_BOT_TOKEN` | — | Telegram bot token (optional — can also be set in **Settings → Notifications**) |
| `TELEGRAM_CHAT_ID` | — | Telegram chat ID (optional — can also be set in **Settings → Notifications**) |

> On first run (no `DATABASE_URL` set), CoolifyGo self-bootstraps: generates secrets, starts managed Postgres + Redis containers via Docker, and writes `/data/coolifygo/.env` automatically.

---

## One-Click Services

Deploy any of these from **Services → + New Service**:

| Service | Category |
|---|---|
| Nextcloud | File storage / productivity |
| Redis Stack | Redis + RedisInsight UI |
| Uptime Kuma | Status monitoring |
| Grafana | Metrics dashboards |
| Prometheus | Metrics collection |
| Vaultwarden | Bitwarden-compatible password manager |
| Gitea | Self-hosted Git service (GitHub-compatible API) |

---

## Auto-Deploy Webhooks

Every application has a webhook URL:

```
POST /api/v1/webhook/{appID}
```

Add it to your Git provider's push webhook settings. On every push coolifygo creates a new deployment and runs the full pipeline automatically.

Toggle auto-deploy per app using the button on the application card — when disabled, incoming webhooks are silently ignored.

**GitHub example:**
- Settings → Webhooks → Add webhook
- Payload URL: `http://<server-ip>:3000/api/v1/webhook/<appID>`
- Content type: `application/json`
- Events: `Just the push event`

---

## API

All endpoints live under `/api/v1`. Pass your API token as a Bearer header:

```
Authorization: Bearer cgo_<token>
```

Create tokens at **Settings → API Tokens**.

```
# Auth
GET    /api/v1/auth/setup              ← {"setup_needed": bool} — check if first registration is still open
POST   /api/v1/auth/register           ← only succeeds when no users exist yet
POST   /api/v1/auth/login
POST   /api/v1/auth/forgot-password    ← resets admin password, writes to /data/coolifygo/coolifygo-password.txt
GET    /api/v1/auth/me
PATCH  /api/v1/auth/me                     ← update email
POST   /api/v1/auth/me/password            ← change password (requires current_password)
GET    /api/v1/auth/tokens
POST   /api/v1/auth/tokens
DELETE /api/v1/auth/tokens/{id}

# Teams
GET    /api/v1/teams
POST   /api/v1/teams
GET    /api/v1/teams/{id}
PUT    /api/v1/teams/{id}
DELETE /api/v1/teams/{id}
GET    /api/v1/teams/{id}/members
POST   /api/v1/teams/{id}/members
DELETE /api/v1/teams/{id}/members/{userID}

# Servers (managed internally — no UI)
GET    /api/v1/servers
POST   /api/v1/servers
GET    /api/v1/servers/{id}
PUT    /api/v1/servers/{id}
DELETE /api/v1/servers/{id}
GET    /api/v1/servers/{id}/health
POST   /api/v1/servers/{id}/validate      ← test SSH + Docker connectivity

# Applications
GET    /api/v1/applications?team_id={id}
POST   /api/v1/applications
GET    /api/v1/applications/{id}
PATCH  /api/v1/applications/{id}          ← name, git_repo, branch, build_pack, port,
                                             env_vars, build_args, docker_args, auto_deploy,
                                             compose_service_main, healthcheck_path/port/interval,
                                             push_registry_id, debug_mode, is_bot
DELETE /api/v1/applications/{id}
POST   /api/v1/applications/{id}/deploy             ← ?force=true bypasses Docker layer cache
GET    /api/v1/applications/{id}/deployments
POST   /api/v1/applications/{id}/start
POST   /api/v1/applications/{id}/stop
POST   /api/v1/applications/{id}/restart
GET    /api/v1/applications/{id}/status   ← live container state + healthcheck (.health field)
GET    /api/v1/applications/{id}/stats    ← live CPU/mem/network stats
GET    /api/v1/applications/{id}/logs     ← WebSocket, streams container stdout/stderr
GET    /api/v1/applications/{id}/webhooks          ← last 50 webhook deliveries (signature status, deployed, payload)
POST   /api/v1/applications/{id}/webhooks/rotate-secret  ← generate a new HMAC secret

# Deployments
GET    /api/v1/deployments                ← team's pending+running deploys (Active Deploys panel)
GET    /api/v1/deployments/{id}
POST   /api/v1/deployments/{id}/cancel    ← also called from the dashboard's Cancel buttons
GET    /api/v1/deployments/{id}/logs      ← WebSocket, streams live build output

# Databases
GET    /api/v1/databases?team_id={id}
POST   /api/v1/databases
GET    /api/v1/databases/{id}
PATCH  /api/v1/databases/{id}             ← name, db_user, password, root_*, default_database,
                                             is_public, public_port, backup_enabled, backup_schedule,
                                             backup_telegram_token, backup_telegram_chat_id
DELETE /api/v1/databases/{id}
POST   /api/v1/databases/{id}/start
POST   /api/v1/databases/{id}/stop
POST   /api/v1/databases/{id}/restart
GET    /api/v1/databases/{id}/logs        ← WebSocket, streams container stdout/stderr
GET    /api/v1/databases/{id}/usage       ← live CPU/mem stats
GET    /api/v1/databases/{id}/backups     ← last 30 backup attempts
POST   /api/v1/databases/{id}/backups/run ← manual trigger (gzipped dump → Telegram)

# Git Sources (in-memory, not persisted)
GET    /api/v1/git-sources
POST   /api/v1/git-sources
DELETE /api/v1/git-sources/{id}
GET    /api/v1/git-sources/github-app/manifest  ← generate GitHub App creation URL + manifest
GET    /api/v1/git-sources/github-app/callback  ← public — GitHub redirects here after App creation

# Services
GET    /api/v1/services?team_id={id}
POST   /api/v1/services
GET    /api/v1/services/{id}
DELETE /api/v1/services/{id}
POST   /api/v1/services/{id}/start
POST   /api/v1/services/{id}/stop
POST   /api/v1/services/{id}/restart
GET    /api/v1/services/{id}/logs         ← WebSocket, streams container stdout/stderr
GET    /api/v1/services/templates


# Docker Registries (in-memory, not persisted)
GET    /api/v1/registries
POST   /api/v1/registries
DELETE /api/v1/registries/{id}

# System Settings
GET    /api/v1/settings                   ← get Telegram + other settings
PUT    /api/v1/settings                   ← update settings
POST   /api/v1/settings/test-telegram     ← send a test Telegram message

# Settings
GET    /api/v1/settings                   ← telegram, min_port, max_port, auto_update_enabled
PUT    /api/v1/settings                   ← update any settings field
POST   /api/v1/settings/test-telegram     ← send a test Telegram message

# Maintenance
POST   /api/v1/internal/cleanup           ← Docker prune; ?volumes=true for volumes
POST   /api/v1/internal/reset-queue       ← reset all asynq queues
GET    /api/v1/internal/version           ← {"version":"vX.Y.Z"} — no GHCR hit
GET    /api/v1/internal/update/check      ← GHCR tag check (6h cache); ?force=true to bypass
POST   /api/v1/internal/update/run        ← pull latest image (best-effort pre-warm)
POST   /api/v1/webhook/{appID}            ← Git push auto-deploy (verifies X-Hub-Signature-256 / X-Gitlab-Token when secret set)
GET    /health                            ← {"status":"ok","service":"coolifygo"} or 503 degraded
```

---

## Tech Stack

| Layer | Choice |
|---|---|
| Language | Go 1.26 |
| Router | chi v5 |
| Database | PostgreSQL 17 + pgx/v5 |
| Schema | Single embedded `internal/db/schema.sql`, applied idempotently on every boot — no migrations layer |
| Auth | JWT (golang-jwt/jwt/v5) + bcrypt |
| Docker | Docker SDK v28 — never shells out to the CLI |
| SSH | golang.org/x/crypto/ssh |
| Git | go-git/go-git/v5 |
| WebSockets | gorilla/websocket |
| Async jobs | asynq (Redis-backed) |
| Config | viper + godotenv |
| Logging | zerolog |
| Frontend | Alpine.js v3.14.1 + Tailwind CSS via CDN — no build step, no Node |

---

## Development

```bash
cp .env.example .env
docker compose -f docker/docker-compose.yml up -d
go run ./cmd/server

# hot reload (requires: go install github.com/air-verse/air@latest)
air
```

```bash
make tools          # install air, golangci-lint
make build          # go build -o bin/coolifygo ./cmd/server
make run            # build + run
make dev            # hot reload via air
make test           # go test ./... -v
make test-race      # go test -race ./...
make lint           # golangci-lint run ./...
make vet            # go vet ./...
make docker-build   # build production Docker image
make docker-up      # spin up Postgres + Redis
make docker-down    # tear down
make clean          # rm -rf bin/
make tidy           # go mod tidy
```

Single test:
```bash
go test ./internal/api/... -run TestName
```

---

## Logs

```bash
docker logs coolifygo -f          # follow live logs
docker logs coolifygo --tail 100  # last 100 lines
```

---

## License

MIT
