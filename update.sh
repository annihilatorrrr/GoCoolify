#!/usr/bin/env bash
# CoolifyGo — updater
#
# Pulls the latest image from ghcr.io anonymously, recreates the container,
# and verifies health. All deployed app containers keep running during the
# update (Docker live-restore).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main/update.sh | sudo bash
#   sudo bash update.sh [--skip-apt] [--cleanup-api]
#
# Flags:
#   --skip-apt      Skip system package updates
#   --cleanup-api   Trigger Docker cleanup via the API after update
#
# Rollback if something goes wrong:
#   docker stop coolifygo && docker rm coolifygo
#   docker run -d --name coolifygo --restart no \
#     --network host \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     -v /data/coolifygo:/data/coolifygo \
#     -e COOLIFY_DATA_DIR=/data/coolifygo \
#     -e COOLIFY_PORT=3000 \
#     ghcr.io/annihilatorrrr/coolifygo:bak
#   systemctl restart coolifygo
#
# NEVER run these manually on a coolifygo server:
#   docker image prune -a    ← wipes app images if containers are momentarily stopped
#   docker system prune -a   ← same + removes volumes
#   Use Settings → Docker Cleanup in the dashboard instead.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ok]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
die()     { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

[[ "$EUID" -ne 0 ]] && die "Run as root: sudo bash update.sh"
[ "$(uname -s)" != "Linux" ] && die "Only Linux is supported."

COOLIFY_DIR="${COOLIFY_DIR:-/data/coolifygo}"
COOLIFY_PORT="${COOLIFY_PORT:-3000}"
# Repo source. Edit the default below or pass COOLIFY_REPO=you/yourfork at runtime.
REPO="${COOLIFY_REPO:-annihilatorrrr/coolifygo}"
REPO_RAW="https://raw.githubusercontent.com/annihilatorrrr/gocoolify/main"
IMAGE="ghcr.io/${REPO}:latest"
IMAGE_BAK="ghcr.io/${REPO}:bak"
SKIP_APT=0
CLEANUP_API=0

for arg in "$@"; do
    case "$arg" in
    --skip-apt)    SKIP_APT=1 ;;
    --cleanup-api) CLEANUP_API=1 ;;
    --help|-h)
        echo "Usage: update.sh [--skip-apt] [--cleanup-api]"
        echo ""
        echo "  --skip-apt      Skip apt system package updates"
        echo "  --cleanup-api   Trigger Docker cleanup via API after update"
        echo "                  (requires COOLIFY_API_TOKEN env var)"
        exit 0 ;;
    *) die "Unknown option: $arg" ;;
    esac
done

SERVICE="/etc/systemd/system/coolifygo.service"
[ ! -f "$SERVICE" ] && die "CoolifyGo is not installed. Run: curl -fsSL ${REPO_RAW}/pscripts/install.sh | sudo bash"
[ ! -d "$COOLIFY_DIR" ] && die "Data directory $COOLIFY_DIR not found."

# Read port from running container env if available, fall back to default.
RUNNING_PORT=$(docker inspect coolifygo --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
    | grep '^COOLIFY_PORT=' | cut -d= -f2 || echo "")
PORT="${RUNNING_PORT:-$COOLIFY_PORT}"

echo ""
echo -e "${BOLD}CoolifyGo — Update${NC}"
echo ""
info "Image           : $IMAGE"
info "Port            : $PORT"
echo ""

# ─── Step 1: Tag current image as backup, then pull new image ─────────────────
OLD_IMAGE_ID=$(docker inspect coolifygo --format '{{.Image}}' 2>/dev/null || echo "")
if [ -n "$OLD_IMAGE_ID" ]; then
    docker tag "$OLD_IMAGE_ID" "$IMAGE_BAK" 2>/dev/null || true
    info "Previous image tagged as :bak for rollback"
fi

info "Pulling $IMAGE…"
docker pull "$IMAGE" || die "Failed to pull image. Check network connectivity to ghcr.io."
success "Image pulled"

# ─── Step 2: System packages (optional) ───────────────────────────────────────
if [ $SKIP_APT -eq 0 ] && command -v apt-get &>/dev/null; then
    info "Updating system packages (apt)..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"
    apt-get autoremove -y -qq
    success "System packages updated"

    info "Waiting for Docker daemon..."
    for i in $(seq 1 15); do
        docker info &>/dev/null && break
        sleep 2
    done
    docker info &>/dev/null || die "Docker daemon not responding after apt upgrade"
    success "Docker is ready"
else
    [ $SKIP_APT -eq 1 ] && info "Skipping apt upgrade (--skip-apt)"
fi

# ─── Step 3: Stop old container, recreate with new image ──────────────────────
# Deployed app containers keep running: live-restore=true in daemon config.
info "Stopping CoolifyGo container..."
docker stop coolifygo 2>/dev/null || true
docker wait coolifygo 2>/dev/null || true
success "Container fully stopped (your deployed containers keep running)"

info "Removing old container..."
docker rm coolifygo 2>/dev/null || true
success "Old container removed"

info "Starting new container…"
docker run -d --name coolifygo --restart no --network host -v /var/run/docker.sock:/var/run/docker.sock -v "${COOLIFY_DIR}:/data/coolifygo" -e COOLIFY_DATA_DIR=/data/coolifygo -e COOLIFY_PORT="${PORT}" "${IMAGE}" || die "Failed to start new container. Rollback: docker run ... ${IMAGE_BAK}"
success "Container started"

# ─── Step 4: Health check ─────────────────────────────────────────────────────
info "Waiting for CoolifyGo to be healthy (port $PORT)..."
READY=0
for i in $(seq 1 30); do
    if curl -sf "http://localhost:${PORT}/health" &>/dev/null; then
        READY=1
        break
    fi
    sleep 2
done

if [ $READY -eq 0 ]; then
    warn "Health check timed out — check logs: docker logs coolifygo -f"
    warn "Rollback: docker stop coolifygo && docker rm coolifygo && docker run -d --name coolifygo --restart no -p ${PORT}:${PORT} -v /var/run/docker.sock:/var/run/docker.sock -v ${COOLIFY_DIR}:/data/coolifygo -e COOLIFY_DATA_DIR=/data/coolifygo -e COOLIFY_PORT=${PORT} ${IMAGE_BAK}"
fi

# ─── Step 5: API cleanup (optional) ───────────────────────────────────────────
if [ $CLEANUP_API -eq 1 ] && [ $READY -eq 1 ]; then
    if [[ -n "${COOLIFY_API_TOKEN:-}" ]]; then
        info "Running Docker cleanup via API..."
        curl -sf -X POST "http://localhost:${PORT}/api/v1/internal/cleanup" \
            -H "Authorization: Bearer $COOLIFY_API_TOKEN" >/dev/null \
            && success "Docker cleanup triggered" \
            || warn "Cleanup request failed — run it from Settings → Docker Cleanup"
    else
        warn "Set COOLIFY_API_TOKEN env var to use --cleanup-api, or use Settings → Docker Cleanup"
    fi
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
SERVER_IP=$(hostname -I | awk '{print $1}')
echo ""
if [ $READY -eq 1 ]; then
    echo -e "${GREEN}${BOLD}Update complete!${NC}"
else
    echo -e "${YELLOW}${BOLD}Container recreated — still starting up.${NC}"
fi
echo ""
echo -e "  Dashboard : http://${SERVER_IP}:${PORT}"
echo -e "  Logs      : docker logs coolifygo -f"
echo -e "  Rollback  : docker stop coolifygo && docker rm coolifygo && docker run -d --name coolifygo --restart no -p ${PORT}:${PORT} -v /var/run/docker.sock:/var/run/docker.sock -v ${COOLIFY_DIR}:/data/coolifygo -e COOLIFY_DATA_DIR=/data/coolifygo -e COOLIFY_PORT=${PORT} ${IMAGE_BAK}"
echo ""
echo -e "${YELLOW}${BOLD}REMINDER:${NC} Never run 'docker image prune -a' directly on this server."
echo -e "          Use Settings → Docker Cleanup in the dashboard instead."
echo ""
