# CoolifyGo ✨

A pure mini reimplementation of [Coolify's v3 Branch](https://github.com/coollabsio/coolify) in Go — a self-hosted PaaS for deploying applications, databases, and services via Docker and SSH.

> 🪶 **Single binary. No Node. No PHP. No Laravel. Just Go.**

> Open-source Heroku alternative. Free. Self-hosted. Runs on Raspberry Pi, Oracle Cloud Free Tier (ARM64), or any VPS. Deploys Dockerfile + Docker Compose apps only. Scheduled database backups to Telegram or local disk. Built-in restore from upload or saved backup.

## Code Stats:
[![DeepSource](https://app.deepsource.com/gh/annihilatorrrr/coolifygo.svg/?label=active+issues&show_trend=true&token=ymMYtFVTG4J5NzFqTkiqzwUZ)](https://app.deepsource.com/gh/annihilatorrrr/coolifygo/)

## Note:
> 📦 This repo is just made for actions like Bug reports, Issues, Feature requests, Update, Install, Uninstall only; Codebase is kept private because of heavy commit spam / unwanted or unseen security bugs. If you find one, you can raise an issue to get it fixed. Don't worry — there is no virus/malware in the codebase or binary, test it before using! 🛡️

[![Go](https://img.shields.io/badge/Go-1.26-00ADD8?logo=go)](https://go.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-SDK%20v28-2496ED?logo=docker)](https://docs.docker.com/engine/api/)
[![ghcr.io](https://img.shields.io/badge/ghcr.io-coolifygo-blue?logo=github)](https://ghcr.io/annihilatorrrr/coolifygo)
[![Multi-arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-blueviolet)](https://ghcr.io/annihilatorrrr/coolifygo)
[![Mobile](https://img.shields.io/badge/UI-mobile%20%2B%20desktop-ff69b4)]()

---

## 🗺️ Table of Contents

- [💡 Why CoolifyGo?](#-why-coolifygo)
- [🚀 Features](#-features)
- [⚡ Quick Install](#-quick-install)
- [🔄 Update](#-update)
- [🧹 Uninstall](#-uninstall)
- [🛠️ Getting Started](#️-getting-started)
- [🔑 Forgot Password](#-forgot-password)
- [📦 Manual Setup](#-manual-setup)
- [🌱 Environment Variables](#-environment-variables)
- [🧰 One-Click Services](#-one-click-services)
- [📡 Auto-Deploy Webhooks](#-auto-deploy-webhooks)
- [💾 Backups & Restore](#-backups--restore)
- [🔌 API](#-api)
- [🏗️ Tech Stack](#️-tech-stack)
- [🧪 Development](#-development)
- [📝 License](#-license)

---

## 💡 Why CoolifyGo?

A single Go binary plus Docker is all you need to host **applications, databases, and one-click services** on your own server. No accounts. No per-deployment fees. No opaque control planes. Your box, your data, your rules.

**Common use cases:**

| Use case | Notes |
|---|---|
| 🟢 Replace **Heroku / Render / Vercel** | for personal + side-project hosting |
| ☁️ Run on **free-tier cloud** | Oracle Cloud ARM Ampere A1 (4 vCPU / 24 GB free forever), Hetzner CAX11, AWS Lightsail |
| 🍓 Self-host on a **Raspberry Pi 5** | full ARM64 support, idle footprint under 100 MB RAM |
| 📁 Self-host SaaS apps | Nextcloud, Vaultwarden, Gitea, Grafana, Uptime Kuma — all one-click |
| 🛡️ Self-host **VPN + private DNS** | wg-easy (WireGuard, one-tap from phone) or Headscale (self-hosted Tailscale coordinator); AdGuard Home blocks ads network-wide; DNSCrypt-Proxy encrypts the upstream so your ISP can't read DNS |
| 💾 **Backup-first DB hosting** | every managed Postgres / MySQL / MongoDB / Redis ships scheduled dumps to Telegram or local disk out of the box, plus one-click restore |

---

## 🚀 Features

<details open>
<summary><b>🏗️  Applications</b> — Dockerfile, Docker Compose, inline, or pull-from-image</summary>

- **Deploy Anything** — Deploy anything using Docerfile (Currently only Dockerfile/ Compose YAML is supported!).
- **Git deploys** — clone any public or private repo, build with **Dockerfile** or **Docker Compose**, run with one click. App reachable at `http://<server-ip>:<port>`.
- **Git submodules** — recursive `--init` happens automatically on every clone, in pure Go (matches Coolify v3 behaviour without shelling to `git`).
- **Inline Dockerfile** — paste a Dockerfile in the UI instead of pointing at a repo.
- **Pull-image deploys** — point at any image ref (`nginx:1.27`, `ghcr.io/.../foo:latest`) and CoolifyGo runs it. No build step.
- **Compose multi-service apps** — full `docker-compose.yml` orchestration with healthchecks, `depends_on`, profiles.
- **Force Redeploy** — one-click rebuild that bypasses the Docker layer cache and re-pulls base images.
- **Healthcheck** — HTTP probe (path / port / interval) **or** a custom shell command (`pg_isready`, `curl`, etc.). Live `healthy / unhealthy / starting` badge in the action bar.
- **Build Secrets (Build Args)** — separate `build_args` from runtime `env_vars`. Set them in Secrets tab → Build sub-tab.
- **Push to Registry** — optionally tag and push every successful build to a private registry (GHCR, Docker Hub, GitLab, Quay, ECR).
- **Cancel Build** — abort an in-flight deploy from the Build Logs tab or the dashboard's Active Deploys panel.
- **Full error logs** — when a build fails, the complete persisted log loads, not just the live tail.
- **Deploy Strategy per-app** — `queue_all` (default), `latest_wins` (drop pending, deploy the newest), or `cancel_redeploy` (cancel running build, start fresh).
- **Extra Docker Args** — per-app raw `--memory=512m --cpus=1.5 --cap-add=SYS_PTRACE --add-host=…` applied at deploy time.
- **Sysctls + Init** — `HostConfig.Sysctls` (e.g. `net.core.somaxconn=1024`) and `HostConfig.Init=true` (zombie reaping) toggleable in the UI.
- **Bot apps** — set `is_bot=true` and the app runs without a host port binding (Discord/Telegram bots, workers). Reachable on the internal `coolify` Docker network by container name.
- **Webhook Audit Tab** — per-app last 50 webhook deliveries with signature status, deploy outcome, raw payload.
- **🔒 Config Lock** — build-affecting fields are read-only while a deploy is running so a mid-flight edit can't break the running build. **Name** and **Auto-Deploy** stay editable in every state.

</details>

<details>
<summary><b>🗄️  Managed Databases</b> — PostgreSQL · MySQL · MongoDB · Redis and more ...</summary>

- **Versions:** PostgreSQL 12 → 18, MySQL 8.0/5.7, MongoDB 4.4/5.0/6.0/7.0, Redis 6.0/6.2/7.0/7.2.
- **One-click create wizard** — pick type, version, port. Root + app credentials auto-generated and shown.
- **Auto port allocation** — toggle "Expose publicly" and a free host port is assigned from your configured range (default 9000–9100).
- **Internal + external connection strings** — internal uses the container hostname for in-network apps; external shows server IP + public port when exposed.
- **🐘 Shared PostgreSQL Cluster Mode** (opt-in) — flip a toggle in **Settings → Databases** and every "PostgreSQL database" you create becomes a logical DB inside **one** shared Postgres container instead of one container per DB. Saves dozens of GB of RAM when you host many small bots / workers. Each logical gets its own user, database, isolated permissions, dedicated backup / restore / vacuum schedule, and a ready-to-copy `postgresql://` connection URL. Cluster can optionally be made public (binds a host port) for external clients; logicals stay private. Minor PG version upgrades are one-click; majors need a manual dump-restore. Toggle is symmetric and only available when you have zero PG rows so you can't trap yourself in one mode.
- **🧹 VACUUM FULL** (Postgres) — one-click reclaim from the Databases UI. Live progress output. Safe to run on busy databases.
- **Per-database logs + CPU/mem stats** — live WebSocket stream.

</details>

<details open>
<summary><b>💾 Backups & Restore</b> — scheduled, manual, one-click restore (NEW ⭐)</summary>

- **📅 Scheduled backups** — per-DB cron schedule with a **preset dropdown** (Off / Hourly / Every 6 h / Every 12 h / Daily 1 AM / Daily 4 AM / Daily midnight / Weekly Sunday / Monthly / Custom) plus free-text cron input.
- **🔧 Compressed dumps** — every DB type gets a format-native compressed dump (Postgres custom format, MySQL gzip, MongoDB gzipped archive, Redis RDB) — small and fast to upload.
- **📨 Telegram delivery** — dump streamed as a Telegram document. 50 MB pre-flight + Telegram rate-limit retry handled automatically.
- **🎯 Per-DB Telegram override** — give one database a different bot/chat for a noisy app, falls back to global settings otherwise.
- **💽 Local fallback** — when no Telegram is configured, dumps land safely on disk under your data directory. Last 2 files kept per DB.
- **♻️ One-click Restore** — upload a dump file **OR** pick from saved local backups. Live log during restore. Works with both Postgres binary dumps and plain-text `.sql` files. MySQL, MongoDB, Redis all symmetric to backup.
- **🎛️ Restore flags** — Postgres options surfaced as checkboxes: **Clean**, **Create**, **Data only**, **Schema only**.
- **🏠 Self-backup (coolifygo's own DB)** — back up the platform's own state (users, apps, settings, encrypted credentials) on its own cron. Toggle to use the global Notifications Telegram or a dedicated bot/chat.
- **🔁 Self-restore** — restore the platform DB from an uploaded `.dump` file or saved local backup. Perfect for **migrating CoolifyGo between hosts**.
- **📜 Backup history** — last 3 attempts per DB shown in the UI with status, size, error message on failure.
- **⚠️ Git LFS detection** — clone-time warning when `.gitattributes` declares LFS-tracked files (with workaround recipe), so missing-asset bugs are caught before they reach the build log.

</details>

<details>
<summary><b>⚙️  Platform Operations</b></summary>

- **🆙 Self-Update from the UI** — Settings → Updates checks GHCR for newer tags, "Update Now" spawns a one-shot helper container that swaps the running CoolifyGo in place (~5 s downtime). Previous image tagged `:bak` for emergency rollback. Auto-update toggle pulls the latest image daily so the next manual swap is instant.
- **🔁 Self-Restart from the UI** — same helper-container pattern, no pull, useful after editing env vars on the host.
- **🩹 Boot Reconciler** — 60-second ticker recreates any container marked "running" in the DB that Docker has lost track of (crash-loop exhausted, manually stopped, daemon hiccup). Closes the gap Docker's `unless-stopped` policy leaves after backoff exhaustion.
- **🧼 Cleanup Scheduler** — image prune, stopped-container prune, build-cache prune every 15 minutes. Optional volume prune is manual-only. Disk-usage warning badge above a configurable threshold.
- **🚦 Active Deploys Panel** — pinned to the dashboard, live cancel buttons, 5-second auto-refresh.
- **📜 Activity Log** — last 25 hours of state-changing requests, searchable in **Settings → Security Log**. Useful for spotting unexpected actions or unfamiliar IPs.
- **📊 Runtime Stats Panel** — memory, GC, job queue depths, Postgres DB size, Redis memory + key count, connection-pool counters. Polled every 5 seconds on the Servers page.
- **📺 Real-time Logs** — live WebSocket streaming for app logs, build logs, DB logs, service logs, restore logs.
- **🌍 Global Timezone** — single IANA tz setting drives every cron evaluation, backup filename stamp, and stored-timestamp display in the UI. Default `Asia/Kolkata` (IST), change to anything (UTC, Europe/London, America/New_York, etc.).
- **🖥️ Multi-server fleet** — register additional Linux hosts via SSH key + password-less sudo Docker. Deploy any app/DB/service to any registered server. Health-check button per server.

</details>

<details>
<summary><b>📡 Webhooks & Git Sources</b></summary>

- **GitHub** webhook signature verification (`X-Hub-Signature-256`) with per-app HMAC secret — rotatable from the UI.
- **GitLab** webhook token verification (`X-Gitlab-Token`) — shared secret.
- **Gitea** + **Bitbucket** push webhooks supported.
- **GitHub App** — one-app-many-repos centralised flow. Manifest installation, automatic per-installation tokens (cached in Redis with TTL).
- **🦊 GitLab + 🍃 Gitea OAuth** — paste `client_id` + `client_secret` from the provider's UI, click Authorize, you're in. Same repo + branch picker UX as the GitHub App. Tokens stay fresh automatically.
- **SSH-key sources** — for repos that need ssh:// auth. Keys stored encrypted at rest.
- **🔐 Trust-On-First-Use SSH** — remote servers have their SSH host key captured on first connect and verified on every subsequent dial. Mismatch = refused. Protects against man-in-the-middle on remote hosts.

</details>

<details>
<summary><b>🎨 UI & Workflow</b></summary>

- **📱 Mobile-friendly** — every page is responsive; modals become bottom-sheets on phones, tables scroll horizontally.
- **v3-style dashboard** — `+ Create New Resource` dropdown, Bots / Running / Stopped / Error filter pills, Docker whale icon per app card, BOT badge for headless workers.
- **🔢 Port-suggester** in the create wizards — scans the configured range, checks against existing apps + DBs + a local TCP probe to skip live listeners.
- **⛔ Port conflict guard** — creating or editing an app/DB port is rejected with a clear 409 if that port is already used.
- **🟢 Zero server setup** — the box CoolifyGo runs on is auto-registered as a `type=local` server on first boot. Wizards auto-skip the destination step when only one server exists.
- **👤 Single-user system** — first account is the admin; registration is disabled afterwards.
- **🔑 API tokens** — full REST API, bearer tokens (also accepted as `?token=` for WebSocket connections). Create / revoke from **Settings → API Tokens**.
- **📨 Telegram Notifications** — deploy success/fail and backup outcomes pushed to a chat via **Settings → Notifications**.

</details>

# Min requirements for coolifygo:
- CPU: 1 vCPU (2 recommended — builds can saturate)
- RAM: 1 GB (2 GB recommended). Idle: ~50-100 MB coolifygo + ~30-50 MB Postgres + ~10 MB Redis + Docker daemon ~50-100 MB ≈ 200-250 MB before any user apps.
- Disk: 20 GB (Docker images + build cache add up fast; cleanup runs every 15 min)
- Docker: required (host)
- OS: any 64-bit Linux that runs current Docker; binary is multi-arch (amd64 + arm64).

> Oracle Cloud's Always Free A1 (4 OCPU, 24 GB RAM, ARM) is well above this — perfect fit.

---

## ⚡ Quick Install

### [Migrater (V3 to Go)](https://github.com/annihilatorrrr/coolifyv32Go)

```bash
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/install.sh | sudo bash
```

- 🐳 Pulls the pre-built Docker image from `ghcr.io` — no Go install, no compilation, ~30 seconds
- 🔌 Default port: `3000` — override with `COOLIFY_PORT=8080`
- 📁 Install directory: `/data/coolifygo` — override with `COOLIFY_DIR=/opt/coolifygo`
- ⚙️ Automatically installs Docker if not present
- 🔁 Creates a systemd service (`coolifygo`) that starts on boot

After install, open `http://<server-ip>:3000` and register your first (and only) user.

> 💡 **Reinstall:** Running the install script again performs a clean reinstall — stops the container, pulls the latest image, recreates the container. Your config, deployed containers, databases, and volumes are never touched.

### 🌐 Supported Platforms

The Docker image and standalone binaries ship for both `linux/amd64` and `linux/arm64`. The install script auto-detects architecture.

| Platform | Arch | Notes |
|---|---|---|
| Most VPS / bare metal | `amd64` | Default. ≥1 GB RAM recommended. |
| ☁️ **Oracle Cloud — Ampere A1** | `arm64` | **Best free target.** Up to 4 OCPU / 24 GB RAM free forever. Open dashboard port (3000) in the **VCN security list** and `firewall-cmd --add-port=3000/tcp --permanent`. |
| Oracle Cloud — AMD micro | `amd64` | Tight at 1 GB RAM. Plan 1 small app per VM. |
| 🍓 **Raspberry Pi 5** | `arm64` | 64-bit Pi OS / Ubuntu Server required. 8 GB / 16 GB models comfortably run a handful of apps. |
| Hetzner Cloud (CX / CAX) | both | CAX11 ARM is great budget value. |
| 🍎 Apple Silicon Macs (dev only) | `arm64` | Use Docker Desktop; not for production. |

If you're on a fresh Oracle Linux / RHEL box, the installer's `get.docker.com` step covers both `apt` and `dnf` distros.

---

## 🔄 Update

Pulls the latest image and recreates the container. Deployed containers keep running throughout. Most users won't need this — **Settings → Updates → Update Now** in the dashboard does the same swap from the UI.

### Image + apt packages
```bash
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/update.sh | sudo bash
```
```
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/update.sh | sudo bash -s -- --skip-apt
```
### Docker cleanup via API (needs COOLIFY_API_TOKEN)
```
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/update.sh | \
  sudo COOLIFY_API_TOKEN=cgo_... bash -s -- --cleanup-api
```

The previous image is tagged `:bak` before pulling. To rollback:

> ⚠️ Rollback via :bak only works after update.sh-based updates. The UI "Update Now" automatically cleans up :bak on success — it's only there as an emergency tag if the swap failed.

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

## 🧹 Uninstall

### 1️⃣ Remove CoolifyGo, keep your containers running *(recommended)*

Removes the CoolifyGo container and systemd service. All deployed app containers, databases, and volumes **keep running** — identical to Coolify v3 removal behaviour. Your data directory (`/data/coolifygo`) is preserved so you can reinstall and reconnect later.

```bash
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/uninstall.sh | sudo bash
```

### 2️⃣ Remove everything (full wipe)

Stops and removes all managed containers (apps, databases, one-click services, internal Postgres/Redis) and deletes the data directory.

```bash
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/uninstall.sh | \
  sudo bash -s -- --full -y
```

### 3️⃣ Remove everything including Docker

```bash
curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/uninstall.sh | \
  sudo bash -s -- --full --purge-docker -y
```

---

## 🛠️ Getting Started

### 1. Register & Log In

Open `http://<server-ip>:3000`. Register the first (and only) account — this becomes the admin. **Registration is permanently disabled after the first user is created.** A local Docker server is automatically provisioned for you — no manual server setup ever needed.

### 2. Deploy an Application

Go to **Applications → + New Application**. A 3-step wizard guides you through:

1. 📦 **Select Source** — Public Git URL, private repo via Git Source token/SSH key, GitHub App, paste-a-Dockerfile, or pull a pre-built image
2. 🏗️ **Build Pack** — Dockerfile or Docker Compose
3. ⚙️ **Configure** — set Name, Port, Healthcheck, Deploy Strategy

Click **Deploy**. Build logs stream live in the dashboard. Once running, the app is accessible at `http://<serverIP>:<port>`.

The auto-deploy toggle on each app card enables/disables webhook-triggered deploys per app.

**🔧 Extra Docker Args:** In the app's **Configuration** tab, the _Extra Docker Args_ field accepts raw `docker run` flags applied at deploy time:

```
--memory=512m --cpus=1.5 --cap-add=SYS_PTRACE --add-host=mydb:192.168.1.10
```

### 3. Deploy a Database

Go to **Databases → + New Database**, walk through the wizard (type → version → configure) and deploy. Connection strings are shown in the database detail panel. Optional public exposure assigns a host port from the configured range.

### 4. Enable Scheduled Backups

In the database's **Backups** tab, flip the toggle, pick a preset (or write a cron expression), and click **Save schedule**. Backups dump to Telegram if configured under **Settings → Notifications**, otherwise to local disk under `/data/coolifygo/backups/<slug>/`. **Run Backup Now** triggers an on-demand dump. **Restore from file…** opens a modal where you can upload a dump or pick from saved local backups.

### 5. Configure Telegram Notifications

Go to **Settings → Notifications**. Enter your Bot Token and Chat ID, hit **Save**, then **Send Test Message** to verify. Notifications use rich HTML formatting with emoji, commit hash, deploy duration, app URL, and failure reason.

### 6. (Optional) Set Your Timezone

Go to **Settings → Updates**. Pick your IANA timezone (default `Asia/Kolkata` / IST). All cron schedules, backup filenames, and UI timestamps follow this zone.

---

## 🔑 Forgot Password

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

## 📦 Manual Setup

### Requirements

- 🐧 Linux (x86_64 or arm64)
- 🐳 Docker ≥ 24 with Compose v2 (`docker compose version`)

> 💡 PostgreSQL and Redis are **not** required upfront — CoolifyGo self-bootstraps them as Docker containers on first run.

### Run via Docker *(recommended)*

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

### Build Docker Image locally

```bash
docker build -f docker/Dockerfile -t coolifygo:latest .
```

Two-stage build (`golang:1.26-alpine` builder → `alpine:3.23` runtime). Final image bundles the Docker CLI + Compose plugin so multi-service apps work out of the box. Multi-arch via Go cross-compilation (no QEMU emulation needed) — fast builds for both `amd64` and `arm64`.

---

## 🌱 Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | auto | PostgreSQL DSN. Auto-generated on first boot if unset. |
| `JWT_SECRET` | auto | Token signing secret. Auto-generated on first boot if unset. |
| `REDIS_URL` | `redis://localhost:6379` | Redis for the async job queue + caches. |
| `APP_ENV` | `development` | Set to `production` for JSON logging. |
| `SERVER_PORT` | `3000` | HTTP listen port (also overridable via `-port` flag). |
| `JWT_EXPIRY_HOURS` | `24` | Session lifetime in hours. UI silently refreshes every 30 minutes. |
| `DOCKER_CLEANUP_THRESHOLD` | `80` | Disk usage % that lights up the cleanup warning badge. |
| `COOLIFY_DATA_DIR` | `/data/coolifygo` | Data directory — must match the volume mount path. |
| `TELEGRAM_BOT_TOKEN` | — | Telegram bot token (optional — can also be set in **Settings → Notifications**). |
| `TELEGRAM_CHAT_ID` | — | Telegram chat ID (optional — can also be set in **Settings → Notifications**). |

> 🪄 On first run (no `DATABASE_URL` set), CoolifyGo self-bootstraps: generates secrets, starts managed Postgres + Redis containers via Docker, and writes `/data/coolifygo/.env` automatically.

---

## 🧰 One-Click Services

Deploy any of these from **Services → + New Service**:

| Service | Category | What it does |
|---|---|---|
| 📁 **Nextcloud** | File storage / productivity | Self-hosted Dropbox/Google Drive — files, calendar, contacts, office suite |
| 🧠 **Redis Stack** | Key-value + UI | Redis + RedisInsight web UI |
| 📈 **Uptime Kuma** | Status monitoring | Self-hosted status page + ping monitor |
| 📊 **Grafana** | Metrics dashboards | Dashboards on top of Prometheus, InfluxDB, etc. |
| 📡 **Prometheus** | Metrics collection | Time-series scraping + storage |
| 🔐 **Vaultwarden** | Password manager | Self-hosted Bitwarden-compatible vault |
| 🐙 **Gitea** | Self-hosted Git | Lightweight GitHub-compatible Git service |
| ✍️ **Ghost** | Blog / CMS | Modern headless publishing platform |
| 📸 **Immich** | Photos & videos | Self-hosted Google Photos replacement with face recognition |
| 🛂 **Authentik** | SSO / IdP | OIDC + SAML + LDAP identity provider |
| 📄 **Stirling-PDF** | PDF utilities | In-browser merge / split / OCR / sign |
| 📂 **File Browser** | File management | Web UI for browsing and managing a directory tree |
| 🔁 **n8n** | Workflow automation | Zapier-style flows with 400+ integrations |
| 🗃️ **Adminer** | DB management | Universal database UI (single PHP file) |
| 🐛 **GlitchTip** | Error tracking | Sentry-compatible error/performance monitoring |
| ✈️ **Teleproxy** | Telegram proxy | MTProto proxy with fake-TLS camouflage + DPI resistance |
| 🛡️ **wg-easy** | WireGuard VPN | Self-hosted VPN with admin web UI — one-tap connect from the WireGuard phone app |
| 🚫 **AdGuard Home** | DNS ad blocker | Network-wide ad/tracker blocking — your own `dns.adguard.com` |
| 🔒 **DNSCrypt-Proxy** | Encrypted DNS upstream | DoH / DNSCrypt forwarder — pair with AdGuard to hide DNS lookups from your ISP |
| 🌐 **Headscale** | Mesh VPN | Self-hosted Tailscale coordinator — devices use the official Tailscale apps (one-tap connect) |

Each detail page surfaces admin URLs + first-login credentials in a quick-access panel.

**🔄 Update with instant + 10-min Rollback** — the **Update** button on every service pulls the latest images and recreates the stack. If pull or compose-up fails, the previous images are automatically restored (instant rollback, you never see the broken state). On success a **Rollback** button stays visible for 10 minutes so you can flip back to the previous images if the new version misbehaves. Data volumes are not rolled back — only image refs.

---

## 📡 Auto-Deploy Webhooks

Every application has a webhook URL:

```
POST /api/v1/webhook/{appID}
```

Add it to your Git provider's push webhook settings. On every push CoolifyGo creates a new deployment and runs the full pipeline automatically.

Toggle auto-deploy per app using the button on the application card — when disabled, incoming webhooks are silently ignored.

**🐙 GitHub example:**
- Settings → Webhooks → Add webhook
- Payload URL: `http://<server-ip>:3000/api/v1/webhook/<appID>`
- Content type: `application/json`
- Events: `Just the push event`

> 🏢 For multi-repo fleets, prefer the **GitHub App** flow — one app, automatic per-installation tokens, no per-repo webhook setup. Create it from **Settings → Git Sources → New → GitHub App**.

---

## 💾 Backups & Restore

Every managed database (Postgres / MySQL / MongoDB / Redis) ships scheduled backups out of the box.

**📅 Schedule:** preset dropdown (Off / Hourly / Every 6 h / Every 12 h / Daily 1 AM / Daily 4 AM / Daily midnight / Weekly Sunday / Monthly / Custom) or write a custom cron string. Evaluated in the global timezone (Settings → Updates).

**🎯 Destination:** Telegram bot/chat (per-DB override or global) **OR** local disk at `/data/coolifygo/backups/<slug>/` when no Telegram is configured. 50 MB Telegram pre-flight + rate-limit retry handled automatically.

**♻️ Restore:**
- Upload a dump file from your machine, OR pick from saved local backups in a dropdown.
- **Postgres:** handles both binary dumps and plain-text `.sql` / `.sql.gz`. Flag checkboxes: Clean / Create / Data-only / Schema-only.
- **MySQL:** gzipped SQL.
- **MongoDB:** gzipped archive.
- **Redis:** swaps the RDB and auto-restarts (~2 s downtime).
- Live log stream during the entire operation.

**🏠 Self-Backup:** CoolifyGo can back up its own state (users, apps, settings, encrypted credentials) on its own cron. Configure under **Settings → Updates → Self-backup**. Choose between sharing the global Notifications Telegram or setting a dedicated bot/chat for system backups only. Restore from upload or saved local file — perfect for **migrating CoolifyGo between hosts**.

---

## 🔌 API

All endpoints live under `/api/v1`. Pass your API token as a Bearer header:

```
Authorization: Bearer cgo_<token>
```

Create tokens at **Settings → API Tokens**. WebSocket endpoints also accept `?token=cgo_<token>` for browser-friendly auth.

<details>
<summary><b>👤 Auth</b></summary>

```
GET    /api/v1/auth/setup                  ← {"setup_needed": bool}
POST   /api/v1/auth/register               ← only succeeds when no users exist yet
POST   /api/v1/auth/login
POST   /api/v1/auth/forgot-password        ← writes new password to /data/coolifygo/coolifygo-password.txt
GET    /api/v1/auth/me
PATCH  /api/v1/auth/me                     ← update email
POST   /api/v1/auth/me/password            ← change password (requires current_password)
GET    /api/v1/auth/tokens
POST   /api/v1/auth/tokens
DELETE /api/v1/auth/tokens/{id}
```

</details>

<details>
<summary><b>🖥️ Servers</b></summary>

```
GET    /api/v1/servers
POST   /api/v1/servers
GET    /api/v1/servers/{id}
PUT    /api/v1/servers/{id}
DELETE /api/v1/servers/{id}
GET    /api/v1/servers/{id}/health
POST   /api/v1/servers/{id}/validate       ← test SSH + Docker connectivity
```

</details>

<details>
<summary><b>🏗️ Applications</b></summary>

```
GET    /api/v1/applications
POST   /api/v1/applications
GET    /api/v1/applications/{id}
PATCH  /api/v1/applications/{id}
DELETE /api/v1/applications/{id}
POST   /api/v1/applications/{id}/deploy
GET    /api/v1/applications/{id}/deployments
POST   /api/v1/applications/{id}/queue/cancel       ← drain pending queued deploys
POST   /api/v1/applications/{id}/start
POST   /api/v1/applications/{id}/stop
POST   /api/v1/applications/{id}/restart
GET    /api/v1/applications/{id}/status             ← live container state + healthcheck
GET    /api/v1/applications/{id}/stats              ← live CPU/mem/network
GET    /api/v1/applications/{id}/logs               ← WebSocket — container stdout/stderr
GET    /api/v1/applications/{id}/webhooks           ← last 50 webhook deliveries
POST   /api/v1/applications/{id}/webhooks/rotate-secret  ← rotate HMAC secret
```

</details>

<details>
<summary><b>🚀 Deployments</b></summary>

```
GET    /api/v1/deployments
GET    /api/v1/deployments/{id}
POST   /api/v1/deployments/{id}/cancel
GET    /api/v1/deployments/{id}/logs                ← WebSocket — live build output
```

</details>

<details>
<summary><b>🗄️ Databases · Backups · Restore</b></summary>

```
GET    /api/v1/databases
POST   /api/v1/databases
GET    /api/v1/databases/{id}
PATCH  /api/v1/databases/{id}
DELETE /api/v1/databases/{id}
GET    /api/v1/databases/{id}/status
POST   /api/v1/databases/{id}/start
POST   /api/v1/databases/{id}/stop
POST   /api/v1/databases/{id}/restart
GET    /api/v1/databases/{id}/logs                  ← WebSocket
GET    /api/v1/databases/{id}/usage                 ← live CPU/mem
GET    /api/v1/databases/{id}/backups               ← last 3 backup attempts
POST   /api/v1/databases/{id}/backups/run           ← manual trigger
GET    /api/v1/databases/{id}/restores              ← last 3 restore attempts
POST   /api/v1/databases/{id}/restore               ← multipart upload OR {"local_name","flags"}
GET    /api/v1/databases/{id}/restores/{aID}/logs   ← WebSocket — live restore log
GET    /api/v1/databases/{id}/local-backups         ← saved dumps for the restore dropdown
POST   /api/v1/databases/{id}/vacuum                ← Postgres VACUUM FULL (plain-text stream)
```

</details>

<details>
<summary><b>🐙 Git Sources · 🧰 Services · 📦 Registries</b></summary>

```
GET    /api/v1/git-sources
POST   /api/v1/git-sources
DELETE /api/v1/git-sources/{id}
GET    /api/v1/git-sources/github-app/manifest      ← generate GitHub App creation URL + manifest
GET    /api/v1/git-sources/github-app/callback      ← public — GitHub redirects here after App creation

GET    /api/v1/services
POST   /api/v1/services
GET    /api/v1/services/{id}
DELETE /api/v1/services/{id}
POST   /api/v1/services/{id}/start
POST   /api/v1/services/{id}/stop
POST   /api/v1/services/{id}/restart
GET    /api/v1/services/{id}/logs                   ← WebSocket
GET    /api/v1/services/templates

GET    /api/v1/registries
POST   /api/v1/registries
DELETE /api/v1/registries/{id}
```

</details>

<details>
<summary><b>⚙️ Settings · 🏠 System backup/restore · 🧰 Maintenance</b></summary>

```
GET    /api/v1/settings
PUT    /api/v1/settings
POST   /api/v1/settings/test-telegram               ← send a test Telegram message

# System self-backup + restore (coolifygo's own Postgres)
GET    /api/v1/internal/system-backup               ← attempts + live settings
POST   /api/v1/internal/system-backup/run           ← manual trigger
GET    /api/v1/internal/system-backup/local         ← saved dumps under /data/coolifygo/backups/_system/
GET    /api/v1/internal/system-restore              ← restore-attempt history
POST   /api/v1/internal/system-restore/run          ← upload OR local pick — returns {attempt_id}
GET    /api/v1/internal/system-restore/{aID}/logs   ← WebSocket — live restore log

# Maintenance & Platform
POST   /api/v1/internal/cleanup                     ← Docker prune; ?volumes=true for volumes
POST   /api/v1/internal/cleanup/unconfigured        ← drop half-made apps/dbs/services older than 1 h
POST   /api/v1/internal/reset-queue                 ← reset background job queues
GET    /api/v1/internal/version                     ← current version
GET    /api/v1/internal/update/check                ← GHCR tag check (cached); ?force=true to bypass
POST   /api/v1/internal/update/run                  ← swap to latest image via helper container
POST   /api/v1/internal/restart                     ← recreate the CoolifyGo container in place
GET    /api/v1/internal/audit-log                   ← last 25h of state-changing requests
GET    /api/v1/internal/runtime-stats               ← goroutines, mem, queue depths, DB sizes
GET    /api/v1/internal/suggest-port                ← next-free port helper for create wizards
POST   /api/v1/webhook/{appID}                      ← Git push auto-deploy
POST   /api/v1/webhook/github                       ← centralised GitHub App webhook
GET    /health                                      ← {"status":"ok","service":"coolifygo"} or 503
```

</details>

---

## 🏗️ Tech Stack

| Layer | Choice |
|---|---|
| Language | 🐹 Go 1.26 |
| Router | chi v5 |
| Database | 🐘 PostgreSQL v17 + pgx/v5 |
| Schema | Single embedded schema, applied idempotently on every boot — no migrations layer to manage |
| Docker | 🐳 Docker SDK v28 — pure Go, no shell-out (except Compose plugin) |
| SSH | golang.org/x/crypto/ssh |
| Git | go-git/go-git/v5 — recursive submodules, native HTTPS + SSH transports |
| WebSockets | gorilla/websocket |
| Async jobs | asynq (Redis v7 - backed) |
| Logging | zerolog |
| Timezone DB | embedded via `time/tzdata` — works on scratch / distroless / minimal alpine without a host `tzdata` package |
| Frontend | ✨ Alpine.js v3.15 + Tailwind CSS 3 — **vendored** into `web/dist/static/`, embedded via `go:embed`. **No npm, no Node, no build step, no CDN at runtime.** |

---

## 🧪 Development

### Logs

```bash
docker logs coolifygo -f          # follow live logs
docker logs coolifygo --tail 100  # last 100 lines
```

---

## 📝 License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <sub>Made with 🐹 and a stubborn refusal to install Node.</sub>
</p>

<!--
Keywords (for search): self-hosted PaaS, Coolify alternative, Heroku alternative, Render alternative,
Vercel alternative, free PaaS, Docker deployment, Go PaaS, Raspberry Pi PaaS, Oracle Cloud
Free Tier, ARM64 deployment, self-host applications, self-host databases, Telegram backups,
scheduled database backups, PostgreSQL backup, MySQL backup, MongoDB backup, Redis backup,
Docker Compose deployment, GitHub auto-deploy, self-hosted Heroku, free hosting, Docker SDK Go,
Coolify v3 Go rewrite, CoolifyGo, Coolify go, Nextcloud one-click, Vaultwarden one-click,
Gitea one-click, Uptime Kuma, one-click, Grafana self-host, Prometheus self-host,
self-host PaaS Go single binary, restore PostgreSQL from dump, restore MySQL backup,
restore MongoDB archive, Redis RDB restore, self-hosted VPN, self-host WireGuard, wg-easy,
WireGuard web UI, self-hosted Tailscale, Headscale, mesh VPN, self-hosted DNS, AdGuard Home,
network-wide ad blocker, encrypted DNS, DNS over HTTPS, DoH, DNSCrypt, dnscrypt-proxy,
hide DNS from ISP, self-hosted dns.adguard.com.
-->
