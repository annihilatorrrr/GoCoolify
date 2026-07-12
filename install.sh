#!/usr/bin/env bash
# CoolifyGo installer
#
# CoolifyGo is self-bootstrapping: on first run it generates its own secrets,
# starts managed Postgres + Redis containers, and writes its own config.
# This script only needs to: install Docker, pull the image, and set up systemd.

[ ! -n "$BASH_VERSION" ] && echo "You can only run this script with bash, not sh / dash." && exit 1

set -euo pipefail

SCRIPT_VERSION="v2.0.0"
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)   DOCKER_PLATFORM="linux/amd64" ;;
    aarch64|arm64)  DOCKER_PLATFORM="linux/arm64" ;;
    armv7l)         DOCKER_PLATFORM="linux/arm/v7" ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
WHO=$(whoami)
DEBUG=0
FORCE=0
DOCKER_MAJOR=20
DOCKER_MINOR=10
DOCKER_VERSION_OK="nok"
COOLIFY_PORT="${COOLIFY_PORT:-3000}"
COOLIFY_DIR="${COOLIFY_DIR:-/data/coolifygo}"
# Repo source. Override the default if you fork or mirror — single point of edit.
#   - inline:   change the default below
#   - per-run:  COOLIFY_REPO=you/yourfork bash install.sh
REPO="${COOLIFY_REPO:-annihilatorrrr/coolifygo}"
REPO_RAW="https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main"
IMAGE="ghcr.io/${REPO}:latest"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ok]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
die()     { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

needs_arg() { [ -z "$OPTARG" ] && die "No arg for --$OPT option"; }
errorchecker() {
    exitCode=$?
    [ $exitCode -ne 0 ] && echo "$0 exited unexpectedly with status: $exitCode"
}

# Detect the host's externally-reachable IPv4 — mirrors internal/netutil.OutboundIP
# so the final "Dashboard:" URL matches what the binary itself prints. `hostname -I`
# alone returns the first private VNIC IP on cloud VMs that NAT the public address
# (Oracle Cloud / AWS / GCP), giving the user a URL that doesn't work from outside
# the VPC. Order: PUBLIC_IP env → local outbound IP → echo service when local is
# RFC1918/CGNAT/link-local → fallback.
detect_public_ip() {
    if [ -n "${PUBLIC_IP:-}" ]; then printf '%s' "$PUBLIC_IP"; return; fi
    local local_ip=""
    if command -v ip >/dev/null 2>&1; then
        local_ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk 'NR==1 {for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')
    fi
    if [ -z "$local_ip" ] && command -v hostname >/dev/null 2>&1; then
        local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    local is_private=0
    case "$local_ip" in
        10.*|192.168.*|169.254.*) is_private=1 ;;
        172.1[6-9].*|172.2[0-9].*|172.3[01].*) is_private=1 ;;
        100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*) is_private=1 ;;
    esac
    if [ "$is_private" = "1" ]; then
        local url pub
        for url in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com; do
            pub=$(curl -sf --max-time 2 "$url" 2>/dev/null | tr -d '[:space:]')
            if printf '%s' "$pub" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
                printf '%s' "$pub"; return
            fi
        done
    fi
    printf '%s' "${local_ip:-localhost}"
}

restartCoolifyGo() {
    [ ! -f /etc/systemd/system/coolifygo.service ] && die "CoolifyGo service not found. Run the installer first."
    info "Restarting CoolifyGo..."
    systemctl restart coolifygo
    success "Done."
    exit 0
}

docker_run_coolifygo() {
    docker run -d \
        --name coolifygo \
        --restart no \
        --network host \
        -v /var/run:/var/run \
        -v "${COOLIFY_DIR}:/data/coolifygo" \
        -e COOLIFY_DATA_DIR=/data/coolifygo \
        -e COOLIFY_PORT="${COOLIFY_PORT}" \
        "${IMAGE}"
}

# ─── Arg parsing ──────────────────────────────────────────────────────────────
while getopts hvdfr-: OPT; do
    if [ "$OPT" = "-" ]; then
        OPT="${OPTARG%%=*}"
        OPTARG="${OPTARG#$OPT}"
        OPTARG="${OPTARG#=}"
    fi
    case "$OPT" in
    h | help)
        echo -e "CoolifyGo installer $SCRIPT_VERSION
Usage: install.sh [options]
  -h, --help       Show this help menu
  -v, --version    Show script version
  -d, --debug      Verbose output
  -f, --force      No prompts, overwrite everything
  -r, --restart    Restart CoolifyGo service only

To uninstall:
  curl -fsSL ${REPO_RAW}/uninstall.sh | sudo bash

Env overrides (set before running):
  COOLIFY_PORT     Dashboard port     (default: 3000)
  COOLIFY_DIR      Data directory     (default: /data/coolifygo)
  COOLIFY_REPO     GitHub repo path   (default: annihilatorrrr/coolifygo)

CoolifyGo is self-bootstrapping: on first run it automatically generates all
secrets and starts its own managed PostgreSQL and Redis via Docker. No .env
file is needed before running."
        exit 0
        ;;
    v | version) echo "$SCRIPT_VERSION" && exit 0 ;;
    d | debug) DEBUG=1; set -x ;;
    f | force) FORCE=1 ;;
    r | restart) restartCoolifyGo ;;
    ??*) die "Illegal option --$OPT" ;;
    ?) exit 2 ;;
    esac
done
shift $((OPTIND - 1))
trap 'errorchecker' EXIT

# ─── Reinstall detection ──────────────────────────────────────────────────────
REINSTALL=0
if systemctl is-active --quiet coolifygo 2>/dev/null || \
   docker ps -a --filter name='^coolifygo$' --format '{{.Names}}' 2>/dev/null | grep -q '^coolifygo$'; then
    REINSTALL=1
fi

# ─── Banner ───────────────────────────────────────────────────────────────────
cat << 'BANNER'

   ____            _ _  __        ____
  / ___|___   ___ | (_)/ _|_   _ / ___|  ___
 | |   / _ \ / _ \| | | |_| | | | |  _  / _ \
 | |__| (_) | (_) | | |  _| |_| | |_| || (_) |
  \____\___/ \___/|_|_|_|  \__, | \____| \___/
                             |___/

BANNER

if [ $FORCE -ne 1 ]; then
    echo -e "${BOLD}Welcome to the CoolifyGo installer!${NC}"
    echo -e "CoolifyGo will configure itself on first run — no .env editing needed.\n"
fi

# ─── Root check ───────────────────────────────────────────────────────────────
[ "$WHO" != 'root' ] && die "Run as root: sudo bash install.sh"
[ "$(uname -s)" != "Linux" ] && die "Only Linux is supported."

# ─── Reinstall prompt ────────────────────────────────────────────────────────
if [ $REINSTALL -eq 1 ]; then
    if [ $FORCE -eq 0 ]; then
        echo ""
        warn "CoolifyGo is already installed."
        echo ""
        echo -e "  ${BOLD}Reinstall will:${NC}   stop the container, pull latest image, recreate container"
        echo -e "  ${GREEN}${BOLD}Preserved:${NC}        all app containers, databases, volumes, config"
        echo -e "  ${BOLD}Note:${NC}             to update only the image, use update.sh instead"
        echo ""
        read -p "Proceed with reinstall? [Y/n] " yn
        yn="${yn:-Y}"
        case $yn in
        [Nn]*) info "Aborted. To update: curl -fsSL ${REPO_RAW}/update.sh | sudo bash"; exit 0 ;;
        esac
    fi
    echo ""
    info "Stopping existing CoolifyGo container (your deployed containers stay running)..."
    systemctl stop coolifygo 2>/dev/null || true
    docker stop coolifygo 2>/dev/null || true
    docker rm coolifygo 2>/dev/null || true
    success "Container stopped and removed."
    echo ""
fi

# ─── Config summary ───────────────────────────────────────────────────────────
info "Install directory : $COOLIFY_DIR"
info "Dashboard port    : $COOLIFY_PORT"
info "Architecture      : $ARCH"
info "Image             : $IMAGE"
echo ""

# ─── Docker: install if missing ───────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    if [ $FORCE -eq 1 ]; then
        info "Installing Docker..."
        sh -c "$(curl --silent -fsSL https://get.docker.com)"
        systemctl enable --now docker
        success "Docker installed."
    else
        while true; do
            read -p "Docker not found. Install it automatically? [Y/n] " yn
            yn="${yn:-Y}"
            case $yn in
            [Yy]*) info "Installing Docker..."; sh -c "$(curl --silent -fsSL https://get.docker.com)"; systemctl enable --now docker; success "Docker installed."; break ;;
            [Nn]*) die "Install Docker (>= $DOCKER_MAJOR.$DOCKER_MINOR) and re-run." ;;
            *) echo "Please answer Y or N." ;;
            esac
        done
    fi
fi

# ─── Docker: disable Swarm if active (CoolifyGo uses bridge networks) ────────
# CoolifyGo binds host ports directly via the Docker SDK. With Swarm active,
# the ingress mesh hijacks published ports and silently breaks every app/db
# port mapping. Continuing past a failed `swarm leave` would leave the host
# in a broken state that's hard to diagnose later — abort and let the user
# stop whatever's keeping Swarm in standby (workers, services, locked mgr).
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)" = "active" ]; then
    warn "Docker Swarm is active — disabling it so bridge networking works correctly…"
    if docker swarm leave --force >/dev/null 2>&1; then
        success "Docker Swarm disabled."
    else
        die "Could not leave Docker Swarm. CoolifyGo cannot share host ports with the Swarm ingress mesh — run 'docker swarm leave --force' manually and re-run this installer."
    fi
fi

# ─── Oracle Cloud: open iptables INPUT for dashboard + all user-space ports ───
# Oracle Cloud's stock Ubuntu/OL images ship a pre-loaded iptables that REJECTs
# all inbound except SSH. The VCN Security List in the OCI console is a separate
# layer — fixing the cloud side alone still leaves a perfectly-running CoolifyGo
# unreachable from a browser.
#
# We open the full non-privileged TCP range (1024-65535), not just the default
# 9000-9100 allocator range, because:
#   • Apps let users type ANY port in the UI (Application.Port is free-form).
#   • Service templates hard-code wildly varied ports (GlitchTip web 8000,
#     Gitea 3010, Ghost 2368, wg-easy 51821, AdGuard 3020/80…). composeports.Rewrite
#     remaps these to 9000-9100 ONLY when the user doesn't pin them — env-var
#     refs (${PORT}:80), ranges, and many real-world pasted composes survive verbatim.
#   • Custom user-pasted compose YAML is opaque to us at install time.
#   • On OCI, the VCN Security List is the real access gate.
# Privileged ports (<1024) are excluded — docker requires CAP_NET_BIND_SERVICE
# to bind there and users rarely configure that. 22 stays ACCEPTed by Oracle's
# pre-existing rule above the REJECT, untouched.
#
# UDP is NOT auto-opened — opening UDP 1024-65535 wholesale is dangerous
# (memcached/NTP/DNS/chargen amplification reflectors without auth). Users
# running UDP services (wg-easy on 51820, game servers, custom compose) open
# the specific UDP ports manually.
APP_PORT_RANGE="1024:65535"

is_oracle_cloud() {
    if [ -r /sys/class/dmi/id/chassis_asset_tag ] && \
       grep -qi 'OracleCloud' /sys/class/dmi/id/chassis_asset_tag 2>/dev/null; then
        return 0
    fi
    if [ -r /sys/class/dmi/id/sys_vendor ] && \
       grep -qi '^Oracle' /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        return 0
    fi
    return 1
}

has_default_deny_input() {
    iptables -S INPUT 2>/dev/null | grep -qE '^-A INPUT.*-j (REJECT|DROP)'
}

iptables_rules_already_open() {
    iptables -C INPUT -p tcp --dport "$COOLIFY_PORT" -j ACCEPT >/dev/null 2>&1 || return 1
    iptables -C INPUT -p tcp -m multiport --dports "$APP_PORT_RANGE" -j ACCEPT >/dev/null 2>&1 || return 1
    return 0
}

iptables_insert_idempotent() {
    iptables -C INPUT "$@" >/dev/null 2>&1 || iptables -I INPUT "$@"
}

persist_iptables() {
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 && return 0
    fi
    if [ -d /etc/iptables ]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null && return 0
    fi
    if [ -f /etc/sysconfig/iptables ]; then
        iptables-save > /etc/sysconfig/iptables 2>/dev/null && return 0
    fi
    warn "iptables rules added but couldn't auto-persist — they'll vanish on reboot."
    warn "Save manually: sudo iptables-save > /etc/iptables/rules.v4  (or your distro's equivalent)."
    return 1
}

if is_oracle_cloud; then
    if ! command -v iptables >/dev/null 2>&1; then
        warn "Oracle Cloud detected, but no iptables binary found."
        warn "If your firewall is nftables / firewalld / ufw, manually allow:"
        warn "  • TCP ${COOLIFY_PORT} (dashboard)"
        warn "  • TCP ${APP_PORT_RANGE/:/-} (apps, databases, services, custom compose)"
        warn "Also open these in the OCI VCN Security List (Networking → VCN → Subnet → Ingress)."
    elif ! has_default_deny_input; then
        :
    elif iptables_rules_already_open; then
        success "Oracle Cloud iptables already permits dashboard + ${APP_PORT_RANGE/:/-} TCP range."
    else
        warn "Oracle Cloud detected with a default-deny iptables INPUT chain."
        warn "Without ACCEPT rules above the REJECT, the dashboard (port $COOLIFY_PORT) and every"
        warn "deployed app / database / service host port will be silently dropped from outside the VM."
        FIX_IPTABLES=0
        if [ $FORCE -eq 1 ]; then
            FIX_IPTABLES=1
        else
            read -p "Open iptables for dashboard (${COOLIFY_PORT}) + TCP ${APP_PORT_RANGE/:/-}? [Y/n] " yn
            yn="${yn:-Y}"
            case $yn in
            [Yy]*) FIX_IPTABLES=1 ;;
            esac
        fi
        if [ "$FIX_IPTABLES" = "1" ]; then
            info "Inserting iptables ACCEPT rules…"
            INSERT_OK=1
            iptables_insert_idempotent -p tcp --dport "$COOLIFY_PORT" -j ACCEPT || INSERT_OK=0
            iptables_insert_idempotent -p tcp -m multiport --dports "$APP_PORT_RANGE" -j ACCEPT || INSERT_OK=0
            if [ "$INSERT_OK" = "1" ]; then
                persist_iptables && success "iptables opened for dashboard + TCP ${APP_PORT_RANGE/:/-} range."
            else
                warn "Could not insert one or more iptables rules — install continues, but"
                warn "the dashboard and apps will be unreachable from outside until you fix it."
                warn "Common causes:"
                warn "  • firewalld / ufw is running and holds the chain — stop or use its CLI instead"
                warn "  • SELinux / AppArmor blocking root from editing iptables"
                warn "  • Kernel running nf_tables natively with iptables shim rejecting a rule"
                warn "Open manually:"
                warn "  sudo iptables -I INPUT -p tcp --dport ${COOLIFY_PORT} -j ACCEPT"
                warn "  sudo iptables -I INPUT -p tcp -m multiport --dports ${APP_PORT_RANGE} -j ACCEPT"
                warn "  sudo netfilter-persistent save   # Ubuntu/Debian"
                warn "  sudo service iptables save       # Oracle Linux / RHEL"
            fi
        else
            warn "Skipped. To fix manually:"
            warn "  sudo iptables -I INPUT -p tcp --dport ${COOLIFY_PORT} -j ACCEPT"
            warn "  sudo iptables -I INPUT -p tcp -m multiport --dports ${APP_PORT_RANGE} -j ACCEPT"
            warn "  sudo netfilter-persistent save   # Ubuntu/Debian"
            warn "  sudo service iptables save       # Oracle Linux / RHEL"
        fi
        warn "UDP is NOT auto-opened. If you deploy UDP services (wg-easy on 51820,"
        warn "game servers, custom compose), open their specific ports manually — never the whole range."
        warn "Reminder: ALSO open these ports in the OCI VCN Security List"
        warn "(Networking → Virtual Cloud Networks → Subnet → Security List → Ingress)."
        warn "The VCN Security List is the real access gate on OCI — iptables alone won't help."
    fi
fi

# ─── Docker: version check ────────────────────────────────────────────────────
SERVER_VERSION=$(docker version -f "{{.Server.Version}}" 2>/dev/null || echo "0.0")
SERVER_MAJOR=$(echo "$SERVER_VERSION" | cut -d'.' -f1)
SERVER_MINOR=$(echo "$SERVER_VERSION" | cut -d'.' -f2)
if [[ "$SERVER_MAJOR" -gt "$DOCKER_MAJOR" ]] || \
   [[ "$SERVER_MAJOR" -eq "$DOCKER_MAJOR" && "$SERVER_MINOR" -ge "$DOCKER_MINOR" ]]; then
    DOCKER_VERSION_OK="ok"
fi
[ "$DOCKER_VERSION_OK" = "nok" ] && die "Docker $SERVER_VERSION is too old. Need >= $DOCKER_MAJOR.$DOCKER_MINOR."
success "Docker $SERVER_VERSION — OK"

! docker compose version &>/dev/null && die "Docker Compose v2 not found. Update Docker to >= 24."
success "Docker Compose v2 — OK"

# ─── Docker daemon: log rotation + live-restore ───────────────────────────────
DAEMON_JSON="/etc/docker/daemon.json"
configureDocker() {
    mkdir -p /etc/docker/
    cat > "$DAEMON_JSON" <<'DAEMON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "5m", "max-file": "5" },
  "live-restore": true,
  "default-address-pools": [
    { "base": "10.20.0.0/16", "size": 24 }
  ]
}
DAEMON
    systemctl daemon-reload
    systemctl restart docker
    success "Docker daemon configured."
}

if [ -f "$DAEMON_JSON" ]; then
    if [ $FORCE -eq 1 ]; then
        configureDocker
    elif [ $REINSTALL -eq 1 ]; then
        info "Keeping existing Docker daemon configuration."
    else
        while true; do
            read -p "Docker daemon.json already exists. Overwrite? [Y/n] " yn
            yn="${yn:-Y}"
            case $yn in
            [Yy]*) configureDocker; break ;;
            [Nn]*) warn "Keeping existing Docker config."; break ;;
            *) echo "Please answer Y or N." ;;
            esac
        done
    fi
else
    configureDocker
fi

# ─── Install directory ────────────────────────────────────────────────────────
mkdir -p "$COOLIFY_DIR"
success "Data directory: $COOLIFY_DIR"

# ─── Pull image from ghcr.io (anonymous, public package) ──────────────────────
info "Pulling image $IMAGE ($DOCKER_PLATFORM)…"
docker pull --platform "$DOCKER_PLATFORM" "$IMAGE" || die "Failed to pull image. Check network connectivity to ghcr.io."
success "Image pulled."

# ─── Start container ──────────────────────────────────────────────────────────
info "Starting CoolifyGo container…"
docker_run_coolifygo || die "Failed to start CoolifyGo container."
success "Container started."

# ─── systemd service ──────────────────────────────────────────────────────────
# The service file hardcodes /usr/bin/docker so upgrades that temporarily
# move the binary don't break the unit. If docker landed elsewhere, symlink it.
if [ ! -x /usr/bin/docker ]; then
    DOCKER_REAL=$(command -v docker 2>/dev/null) \
        || die "docker not found on PATH"
    ln -sf "$DOCKER_REAL" /usr/bin/docker
    info "symlinked $DOCKER_REAL → /usr/bin/docker for systemd"
fi
cat > /etc/systemd/system/coolifygo.service <<'EOF'
[Unit]
Description=CoolifyGo — Self-hosted PaaS
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/docker start -a coolifygo
ExecStop=/usr/bin/docker stop -t 10 coolifygo
Restart=on-failure
RestartSec=5
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable coolifygo
success "systemd service coolifygo enabled."

# ─── Wait for healthy ─────────────────────────────────────────────────────────
info "Waiting for CoolifyGo to be ready (bootstrapping its own database — may take up to 90s on first run)…"
READY=0
for i in $(seq 1 45); do
    if curl -sf "http://localhost:${COOLIFY_PORT}/health" &>/dev/null; then
        READY=1
        break
    fi
    sleep 2
done

# ─── Done ─────────────────────────────────────────────────────────────────────
SERVER_IP=$(detect_public_ip)
echo ""
if [ $READY -eq 1 ]; then
    if [ $REINSTALL -eq 1 ]; then
        echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║   CoolifyGo reinstalled and running!      ║${NC}"
        echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════╝${NC}"
    else
        echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║   CoolifyGo installed and running!        ║${NC}"
        echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════╝${NC}"
    fi
else
    echo -e "${YELLOW}${BOLD}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║   CoolifyGo installed (still starting…)   ║${NC}"
    echo -e "${YELLOW}${BOLD}║   First run bootstraps Postgres + Redis.  ║${NC}"
    echo -e "${YELLOW}${BOLD}╚═══════════════════════════════════════════╝${NC}"
fi
echo ""
echo -e "  ${BOLD}Dashboard:${NC}  http://${SERVER_IP}:${COOLIFY_PORT}"
echo -e "  ${BOLD}Data dir:${NC}   ${COOLIFY_DIR}  (config auto-generated here on first run)"
echo -e "  ${BOLD}Logs:${NC}       docker logs coolifygo -f"
echo -e "  ${BOLD}Stop:${NC}       systemctl stop coolifygo"
echo -e "  ${BOLD}Restart:${NC}    systemctl restart coolifygo"
echo -e "  ${BOLD}Update:${NC}     curl -fsSL ${REPO_RAW}/update.sh | sudo bash"
echo -e "  ${BOLD}Uninstall:${NC}  curl -fsSL ${REPO_RAW}/uninstall.sh | sudo bash"
echo ""
echo -e "  ${YELLOW}Open the dashboard and register your first admin user.${NC}"
echo ""
echo -e "  ${YELLOW}TIP:${NC} Safe to run 'docker system prune -a' while all containers are running."
echo -e "       Avoid it when coolifygo or app containers are stopped — their local images would be lost."
echo -e "       Or use ${BOLD}Settings → Docker Cleanup${NC} for a always-safe managed prune."
echo ""
