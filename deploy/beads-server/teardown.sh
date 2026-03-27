#!/usr/bin/env bash
# Tear down the BEADS Dolt server created by setup.sh.
# Reads connection info from .beads-server-info.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFO_FILE="${SCRIPT_DIR}/.beads-server-info"

if [[ ! -f "$INFO_FILE" ]]; then
  echo -e "${RED}Error: .beads-server-info not found${NC}"
  echo -e "  Run setup.sh first, or the server was already torn down."
  exit 1
fi

source "$INFO_FILE"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  BEADS Server — Teardown${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Instance:  ${INSTANCE_NAME}"
echo -e "  Project:   ${GCP_PROJECT}"
echo -e "  Zone:      ${ZONE}"
echo -e "  IP:        ${STATIC_IP}"
echo ""
echo -e "${RED}  This will permanently delete the VM and all BEADS data on it.${NC}"
echo ""
read -p "  Type 'yes' to confirm: " CONFIRM
echo ""

if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

# Delete VM (and its disk)
echo -e "${BLUE}▸${NC} Deleting VM..."
gcloud compute instances delete "$INSTANCE_NAME" \
  --zone="$ZONE" \
  --project="$GCP_PROJECT" \
  --delete-disks=all \
  --quiet 2>/dev/null && \
  echo -e "${GREEN}  ✓${NC} VM deleted" || \
  echo -e "${YELLOW}  ⊙${NC} VM not found (already deleted?)"

# Delete firewall rule
echo -e "${BLUE}▸${NC} Deleting firewall rule..."
gcloud compute firewall-rules delete "allow-beads-dolt" \
  --project="$GCP_PROJECT" \
  --quiet 2>/dev/null && \
  echo -e "${GREEN}  ✓${NC} Firewall rule deleted" || \
  echo -e "${YELLOW}  ⊙${NC} Firewall rule not found"

# Release static IP
echo -e "${BLUE}▸${NC} Releasing static IP..."
gcloud compute addresses delete "${INSTANCE_NAME}-ip" \
  --region="${ZONE%-*}" \
  --project="$GCP_PROJECT" \
  --quiet 2>/dev/null && \
  echo -e "${GREEN}  ✓${NC} Static IP released" || \
  echo -e "${YELLOW}  ⊙${NC} Static IP not found"

# Remove info file
rm -f "$INFO_FILE"

echo ""
echo -e "${GREEN}  Teardown complete.${NC} All BEADS server resources deleted."
echo -e "  Update quality-config.json to remove the server block, or set beads.enabled: false"
