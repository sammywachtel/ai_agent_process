#!/usr/bin/env bash
# Start a local Dolt SQL server via Docker with persistent storage.
#
# Data is stored at ~/.dolt-server/data so it survives container
# removal and rebuilds. The container runs in the background with
# --restart unless-stopped (comes back after Docker restarts).
#
# Usage:
#   ./dolt-docker.sh                    # Interactive
#   ./dolt-docker.sh --password mypass  # Non-interactive
#   ./dolt-docker.sh --stop             # Stop the container
#   ./dolt-docker.sh --status           # Check if running
#
# Requires: Docker

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CONTAINER_NAME="beads-dolt-server"
DOLT_DATA_DIR="${DOLT_DATA_DIR:-${HOME}/.dolt-server/data}"
DOLT_CFG_DIR="${DOLT_CFG_DIR:-${HOME}/.dolt-server/config}"
DOLT_PORT="${DOLT_PORT:-3307}"
DOLT_PASSWORD="${DOLT_PASSWORD:-}"

# --- Parse flags ---
ACTION="start"
while [[ $# -gt 0 ]]; do
  case $1 in
    --stop) ACTION="stop"; shift ;;
    --status) ACTION="status"; shift ;;
    --password) DOLT_PASSWORD="$2"; shift 2 ;;
    --port) DOLT_PORT="$2"; shift 2 ;;
    --data-dir) DOLT_DATA_DIR="$2"; shift 2 ;;
    *) echo -e "${RED}Unknown flag: $1${NC}"; exit 1 ;;
  esac
done

# --- Verify Docker ---
if ! command -v docker &>/dev/null; then
  echo -e "${RED}Error: Docker not found.${NC}"
  echo -e "Install from https://docs.docker.com/get-docker/"
  exit 1
fi

# --- Stop ---
if [[ "$ACTION" == "stop" ]]; then
  if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"
    echo -e "${GREEN}✓${NC} Dolt server stopped and removed"
    echo -e "  Data preserved at: ${DOLT_DATA_DIR}"
    echo -e "  Re-run this script to start again"
  else
    echo -e "${YELLOW}⊙${NC} Dolt server is not running"
  fi
  exit 0
fi

# --- Status ---
if [[ "$ACTION" == "status" ]]; then
  if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo -e "${GREEN}✓${NC} Dolt server is running"
    docker ps -f name="$CONTAINER_NAME" --format "  Container: {{.ID}}  Port: {{.Ports}}  Up: {{.Status}}"
    echo -e "  Data: ${DOLT_DATA_DIR}"
  else
    echo -e "${YELLOW}⊙${NC} Dolt server is not running"
  fi
  exit 0
fi

# --- Start ---
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Dolt SQL Server — Docker${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if already running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
  echo -e "${GREEN}  ✓${NC} Dolt server already running on port ${DOLT_PORT}"
  docker ps -f name="$CONTAINER_NAME" --format "  Container: {{.ID}}  Up: {{.Status}}"
  exit 0
fi

# Remove stopped container if it exists (data is on the volume, not in the container)
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Generate password if not provided
if [[ -z "$DOLT_PASSWORD" ]]; then
  DOLT_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 16)
fi

# Create data directories
mkdir -p "$DOLT_DATA_DIR" "$DOLT_CFG_DIR"

echo -e "  Data directory: ${YELLOW}${DOLT_DATA_DIR}${NC}"
echo -e "  Port: ${DOLT_PORT}"
echo ""

# Pull and run
echo -e "${BLUE}▸${NC} Starting Dolt server..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -e DOLT_ROOT_HOST='%' \
  -e DOLT_ROOT_PASSWORD="$DOLT_PASSWORD" \
  -p "${DOLT_PORT}:3306" \
  -v "${DOLT_DATA_DIR}":/var/lib/dolt \
  -v "${DOLT_CFG_DIR}":/etc/dolt/servercfg.d \
  dolthub/dolt-sql-server:latest

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Dolt Server Running${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Host:     ${YELLOW}127.0.0.1${NC}"
echo -e "  Port:     ${YELLOW}${DOLT_PORT}${NC}"
echo -e "  User:     root"
echo -e "  Password: ${YELLOW}${DOLT_PASSWORD}${NC}"
echo -e "  Data:     ${DOLT_DATA_DIR} (persists across container rebuilds)"
echo ""
echo -e "  ${BLUE}For quality-config.json:${NC}"
echo -e '  "beads": {'
echo -e '    "enabled": true,'
echo -e '    "server": { "host": "127.0.0.1", "port": '"${DOLT_PORT}"', "user": "root" }'
echo -e '  }'
echo ""
echo -e "  ${BLUE}Set password:${NC}"
echo -e "  export BEADS_DOLT_PASSWORD=${DOLT_PASSWORD}"
echo ""
echo -e "  ${BLUE}Management:${NC}"
echo -e "  $0 --status    # Check if running"
echo -e "  $0 --stop      # Stop (data preserved)"
