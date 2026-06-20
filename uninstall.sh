#!/usr/bin/env bash
# CoolifyGo uninstaller
#
# Modes:
#   (default / --soft)
#     Removes the CoolifyGo container and systemd service.
#     ALL your deployed app containers, databases, and volumes keep running.
#
#   --full
#     Everything above, PLUS stops and removes all CoolifyGo-managed containers
#     (apps, databases, one-click services, internal Postgres/Redis) and deletes
#     the data directory. Use for a clean-slate wipe.
#
#   --full --purge-docker
#     Full removal + uninstall Docker from the system.
#
# Usage:
#   Soft (keep containers):
#     curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/uninstall.sh | sudo bash
#
#   Full (remove everything):
#     curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/uninstall.sh | sudo bash -s -- --full
#
#   Full + remove Docker:
#     sudo bash uninstall.sh --full --purge-docker

[ ! -n "$BASH_VERSION" ] && echo "You can only run this script with bash, not sh / dash." && exit 1

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ok]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
die()     { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

[[ "$EUID" -ne 0 ]] && die "Run as root: sudo bash uninstall.sh"

COOLIFY_DIR="${COOLIFY_DIR:-/data/coolifygo}"
# Repo source. Edit the default below or pass COOLIFY_REPO=you/yourfork at runtime.
REPO="${COOLIFY_REPO:-annihilatorrrr/coolifygo}"
REPO_RAW="https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main"
IMAGE_BAK="ghcr.io/${REPO}:bak"
MODE="soft"
PURGE_DOCKER=0
FORCE=0

for arg in "$@"; do
    case "$arg" in
    --soft)         MODE="soft" ;;
    --full)         MODE="full" ;;
    --purge-docker) PURGE_DOCKER=1; MODE="full" ;;
    --force|-f|-y)  FORCE=1 ;;
    --help|-h)
        echo "CoolifyGo uninstaller"
        echo ""
        echo "Usage: uninstall.sh [--soft|--full] [--purge-docker] [--force]"
        echo ""
        echo "  --soft (default)   Remove CoolifyGo container + service."
        echo "                     All deployed containers keep running."
        echo "  --full             Also stop all managed containers + delete data dir."
        echo "  --purge-docker     With --full: also uninstall Docker from the system."
        echo "  --force, -f, -y    Skip confirmation prompts."
        exit 0 ;;
    *) die "Unknown option: $arg. Use --help for usage." ;;
    esac
done

# ─── Detect installed version ────────────────────────────────────────────────
INSTALLED_VERSION=$(docker inspect coolifygo --format '{{index .Config.Image}}' 2>/dev/null \
    | sed 's/.*://' || echo "unknown")

# ─── Banner ───────────────────────────────────────────────────────────────────
cat << 'BANNER'

   ____            _ _  __        ____
  / ___|___   ___ | (_)/ _|_   _ / ___|  ___
 | |   / _ \ / _ \| | | |_| | | | |  _  / _ \
 | |__| (_) | (_) | | |  _| |_| | |_| || (_) |
  \____\___/ \___/|_|_|_|  \__, | \____| \___/
                             |___/  Uninstaller

BANNER

# ─── Summary ──────────────────────────────────────────────────────────────────
info "Installed version : $INSTALLED_VERSION"
echo ""
if [ "$MODE" = "soft" ]; then
    echo -e "${BOLD}Mode: Soft removal${NC} (containers keep running)"
    echo ""
    echo -e "  Will remove   : CoolifyGo container, systemd service"
    echo -e "  Will preserve : ${GREEN}all app containers, databases, volumes, config${NC}"
    echo -e "  Data dir      : ${COOLIFY_DIR} (kept — contains your .env)"
else
    echo -e "${BOLD}${RED}Mode: Full removal${NC}"
    echo ""
    echo -e "  Will remove   : CoolifyGo container, systemd service"
    echo -e "  Will remove   : ${RED}ALL managed containers (apps, databases, services)${NC}"
    echo -e "  Will delete   : ${RED}${COOLIFY_DIR} (your data directory)${NC}"
    [ $PURGE_DOCKER -eq 1 ] && \
    echo -e "  Will remove   : ${RED}Docker from this system${NC}"
fi
echo ""

# ─── Confirm ──────────────────────────────────────────────────────────────────
if [ $FORCE -eq 0 ]; then
    if [ "$MODE" = "full" ]; then
        echo -e "${YELLOW}${BOLD}WARNING: This is irreversible. All managed containers and data will be gone.${NC}"
        read -p "Type 'yes' to confirm full removal: " confirm
        [ "$confirm" != "yes" ] && { info "Aborted."; exit 0; }
    else
        read -p "Proceed with soft removal? [Y/n] " yn
        yn="${yn:-Y}"
        case $yn in
        [Nn]*) info "Aborted."; exit 0 ;;
        esac
    fi
fi

echo ""

# ─── Stop & disable systemd service ──────────────────────────────────────────
SERVICE="/etc/systemd/system/coolifygo.service"

if systemctl is-active --quiet coolifygo 2>/dev/null; then
    info "Stopping CoolifyGo service..."
    systemctl stop coolifygo
    success "Service stopped"
fi

if systemctl is-enabled --quiet coolifygo 2>/dev/null; then
    systemctl disable coolifygo 2>/dev/null || true
    success "Service disabled"
fi

if [ -f "$SERVICE" ]; then
    rm -f "$SERVICE"
    systemctl daemon-reload
    success "Service file removed"
fi

# ─── Stop & remove CoolifyGo container ───────────────────────────────────────
if docker ps -a --filter name='^coolifygo$' --format '{{.Names}}' 2>/dev/null | grep -q '^coolifygo$'; then
    info "Stopping and removing CoolifyGo container..."
    docker stop coolifygo 2>/dev/null || true
    docker rm coolifygo 2>/dev/null || true
    success "CoolifyGo container removed"
fi

# Remove any leftover backup image tags created by update.sh.
docker rmi "$IMAGE_BAK" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# SOFT MODE — done here. Containers keep running.
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$MODE" = "soft" ]; then
    RUNNING=0
    if command -v docker &>/dev/null; then
        RUNNING=$(docker ps --filter label=coolifygo.managed=true --format "{{.Names}}" 2>/dev/null | wc -l || echo 0)
    fi

    echo ""
    echo -e "${GREEN}${BOLD}CoolifyGo removed.${NC}"
    echo ""
    echo -e "  Your app containers are still running."
    echo -e "  Managed containers still up: ${BOLD}${RUNNING}${NC}"
    echo ""
    echo -e "  Data dir preserved : ${COOLIFY_DIR}"
    echo -e "  Config preserved   : ${COOLIFY_DIR}/.env"
    echo ""
    echo -e "  To reinstall:"
    echo -e "    curl -fsSL ${REPO_RAW}/pscripts/install.sh | sudo bash"
    echo ""
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FULL MODE — stop and remove all managed containers
# ═══════════════════════════════════════════════════════════════════════════════
if command -v docker &>/dev/null; then
    HAS_COMPOSE=0
    docker compose version &>/dev/null && HAS_COMPOSE=1

    # ── Stage 1: tear down every coolifygo compose project (services + compose-buildpack
    # apps). Project names are `coolifygo-svc-<id8>` for services and `coolifygo-<id8>` for
    # apps. `compose down --volumes` removes containers, project network, AND the project's
    # named volumes in one shot — cleaner than chasing per-volume after the fact.
    if [ $HAS_COMPOSE -eq 1 ]; then
        COMPOSE_PROJECTS=$(docker ps -a \
            --filter label=com.docker.compose.project \
            --format '{{index .Labels "com.docker.compose.project"}}' 2>/dev/null \
            | sort -u | grep '^coolifygo-' || true)
        if [ -n "$COMPOSE_PROJECTS" ]; then
            info "Tearing down coolifygo compose projects..."
            P_COUNT=0
            while IFS= read -r p; do
                [ -z "$p" ] && continue
                docker compose -p "$p" down --remove-orphans --volumes &>/dev/null \
                    && P_COUNT=$((P_COUNT + 1))
            done <<< "$COMPOSE_PROJECTS"
            success "$P_COUNT compose project(s) torn down"
        fi
    fi

    # ── Stage 2: snapshot named volume mounts of remaining managed containers BEFORE
    # deletion. After `rm -f`, `docker inspect` can't resolve the mounts. Covers app
    # + DB containers we run via the SDK directly. Compose-managed ones already gone
    # in stage 1.
    info "Stopping and removing managed containers..."
    MANAGED_IDS=$(docker ps -aq --filter label=coolifygo.managed=true 2>/dev/null || true)
    SNAPSHOTTED_VOLS=""
    if [ -n "$MANAGED_IDS" ]; then
        SNAPSHOTTED_VOLS=$(echo "$MANAGED_IDS" \
            | xargs docker inspect -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null \
            | grep -v '^$' | sort -u || true)
        echo "$MANAGED_IDS" | xargs docker stop --timeout 10 2>/dev/null || true
        echo "$MANAGED_IDS" | xargs docker rm   -f        2>/dev/null || true
        REMOVED=$(echo "$MANAGED_IDS" | wc -l | tr -d ' ')
        success "$REMOVED managed container(s) removed"
    else
        info "No additional managed containers found"
    fi

    # Bootstrap pair fallback by NAME — covers an orphan from a crashed start/stop
    # that lost its label. Also nukes any stale `coolifygo-self` update helper.
    for c in coolifygo-postgres coolifygo-redis coolifygo-self; do
        if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${c}$"; then
            docker rm -f "$c" >/dev/null 2>&1 && success "Removed leftover ${c}"
        fi
    done

    # ── Stage 3: drop the shared coolifygo bridge network. Empty by now.
    info "Removing coolifygo Docker network..."
    docker network rm coolifygo &>/dev/null \
        && success "Network 'coolifygo' removed" \
        || info "Network 'coolifygo' not found or already removed"

    # ── Stage 4: volume sweep. Two-pronged so nothing leaks:
    #   (a) volumes snapshotted from container mounts in stage 2.
    #   (b) name-pattern sweep `^coolifygo-` — catches per-DB `coolifygo-db-<id8>`
    #       (auto-created with no labels), bootstrap `coolifygo-postgres-data` /
    #       `coolifygo-redis-data`, and any prefix-named compose volumes the
    #       project sweep missed (e.g. compose absent). User volumes outside our
    #       prefix are intentionally left alone.
    info "Removing managed Docker volumes..."
    PATTERN_VOLS=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep '^coolifygo-' || true)
    ALL_VOLS=$(printf '%s\n%s\n' "$SNAPSHOTTED_VOLS" "$PATTERN_VOLS" | grep -v '^$' | sort -u || true)
    if [ -n "$ALL_VOLS" ]; then
        V_COUNT=0
        while IFS= read -r v; do
            [ -z "$v" ] && continue
            docker volume rm -f "$v" &>/dev/null && V_COUNT=$((V_COUNT + 1))
        done <<< "$ALL_VOLS"
        success "$V_COUNT volume(s) removed"
    else
        info "No managed volumes found"
    fi

    # ── Stage 5: free disk for a clean reinstall. Safe now — every coolifygo
    # container is gone, so the coolifygo image, layers, and build cache are
    # unreferenced.
    info "Pruning unused images and build cache..."
    docker image prune   -af &>/dev/null && success "Unused images pruned"
    docker builder prune -af &>/dev/null && success "Build cache pruned"
fi

# ─── Wipe stale build/deploy/backup tempdirs ─────────────────────────────────
# coolifygo creates these in $TMPDIR during deploys, compose builds, and DB
# backups. They're normally swept by the in-process `wipeStale(30m)` cleanup,
# but that only runs while the daemon is alive — a process that crashed mid-job
# leaks them forever otherwise.
TMP="${TMPDIR:-/tmp}"
TMP_REMOVED=0
shopt -s nullglob
for d in "$TMP"/coolifygo-deploy-* "$TMP"/coolifygo-compose-* "$TMP"/coolifygo-backup-*; do
    [ -e "$d" ] || continue
    rm -rf -- "$d" && TMP_REMOVED=$((TMP_REMOVED + 1))
done
shopt -u nullglob
[ "$TMP_REMOVED" -gt 0 ] && success "$TMP_REMOVED stale tempdir(s) removed from ${TMP}"

# ─── Delete data directory ────────────────────────────────────────────────────
if [ -d "$COOLIFY_DIR" ]; then
    info "Deleting data directory $COOLIFY_DIR..."
    rm -rf "$COOLIFY_DIR"
    success "Data directory deleted"
fi

# ─── Purge Docker (optional) ─────────────────────────────────────────────────
if [ $PURGE_DOCKER -eq 1 ]; then
    info "Uninstalling Docker..."
    if command -v apt-get &>/dev/null; then
        apt-get purge -y \
            docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin \
            docker-ce-rootless-extras 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        rm -rf /var/lib/docker /etc/docker /var/run/docker.sock
        success "Docker uninstalled"
    else
        warn "Auto-uninstall only supports apt-get. Remove Docker manually for your distro."
    fi
fi

# ─── Oracle Cloud: remove install-time iptables rules ───────────────────────
# Mirror of the rules inserted by install.sh so uninstall is a clean inverse.
# Uses -D (delete) instead of -I (insert); idempotent — no-op if rules absent.
if command -v iptables >/dev/null 2>&1; then
    COOLIFY_PORT_LOCAL="${COOLIFY_PORT:-3000}"
    APP_PORT_RANGE_LOCAL="1024:65535"
    iptables -D INPUT -p tcp --dport "$COOLIFY_PORT_LOCAL" -j ACCEPT >/dev/null 2>&1 || true
    iptables -D INPUT -p tcp -m multiport --dports "$APP_PORT_RANGE_LOCAL" -j ACCEPT >/dev/null 2>&1 || true
    # Persist the removal if possible (same helpers as install.sh).
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 || true
    elif [ -d /etc/iptables ]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    elif [ -f /etc/sysconfig/iptables ]; then
        iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
    fi
    info "Oracle Cloud iptables rules cleaned up (no-op on non-OCI or rules already absent)"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}CoolifyGo fully removed.${NC}"
echo ""
[ $PURGE_DOCKER -eq 0 ] && echo -e "  Docker is still installed on this system."
echo ""
