#!/usr/bin/env bash
# Deploy a Dolt SQL server on GCE e2-micro for BEADS state tracking.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - A GCP project (script will prompt if not set)
#   - Billing enabled on the project
#
# What this creates:
#   - e2-micro VM (~$7/month) with 10GB persistent disk
#   - Dolt SQL server listening on port 3307
#   - Firewall rule allowing 3307 from your specified CIDR
#   - Static external IP (so quality-config.json stays stable)
#
# Usage:
#   ./setup.sh                    # Interactive — prompts for everything
#   ./setup.sh --project my-proj  # Skip project prompt
#
# To tear down:
#   ./teardown.sh

set -euo pipefail

# --- Colors (stolen from install.sh because consistency matters) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  BEADS Server — GCE Deployment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# --- Configuration (override with flags or env vars) ---
INSTANCE_NAME="${BEADS_INSTANCE_NAME:-beads-dolt-server}"
ZONE="${BEADS_ZONE:-us-central1-a}"
MACHINE_TYPE="${BEADS_MACHINE_TYPE:-e2-micro}"
DISK_SIZE="${BEADS_DISK_SIZE:-10GB}"
DOLT_PORT="${BEADS_DOLT_PORT:-3307}"
DOLT_USER="${BEADS_DOLT_USER:-beads}"
DOLT_PASSWORD="${BEADS_DOLT_PASSWORD:-}"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --project) GCP_PROJECT="$2"; shift 2 ;;
    --zone) ZONE="$2"; shift 2 ;;
    --password) DOLT_PASSWORD="$2"; shift 2 ;;
    --allow-cidr) ALLOW_CIDR="$2"; shift 2 ;;
    *) echo -e "${RED}Unknown flag: $1${NC}"; exit 1 ;;
  esac
done

# --- Verify gcloud ---
if ! command -v gcloud &>/dev/null; then
  echo -e "${RED}Error: gcloud CLI not found. Install from https://cloud.google.com/sdk/docs/install${NC}"
  exit 1
fi

# --- Project ---
if [[ -z "${GCP_PROJECT:-}" ]]; then
  CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || true)
  if [[ -n "$CURRENT_PROJECT" ]]; then
    echo -e "  Current GCP project: ${YELLOW}${CURRENT_PROJECT}${NC}"
    read -p "  Use this project? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      GCP_PROJECT="$CURRENT_PROJECT"
    fi
  fi
  if [[ -z "${GCP_PROJECT:-}" ]]; then
    read -p "  Enter GCP project ID: " GCP_PROJECT
  fi
fi
echo -e "${GREEN}  ✓${NC} Project: ${GCP_PROJECT}"

# --- Password ---
if [[ -z "$DOLT_PASSWORD" ]]; then
  # Generate a random password if not provided
  DOLT_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)
  echo -e "${YELLOW}  Generated BEADS password:${NC} ${DOLT_PASSWORD}"
  echo -e "  ${YELLOW}Save this — you'll need it for quality-config.json${NC}"
fi

# --- CIDR for firewall ---
if [[ -z "${ALLOW_CIDR:-}" ]]; then
  echo ""
  echo -e "  Who should be able to connect to this server?"
  echo -e "  1) My current IP only (most secure)"
  echo -e "  2) Any IP (0.0.0.0/0 — easiest, least secure)"
  echo -e "  3) Custom CIDR range"
  read -p "  Choose [1/2/3]: " -n 1 -r
  echo ""
  case $REPLY in
    1)
      MY_IP=$(curl -s https://ifconfig.me 2>/dev/null || curl -s https://api.ipify.org 2>/dev/null)
      if [[ -n "$MY_IP" ]]; then
        ALLOW_CIDR="${MY_IP}/32"
        echo -e "${GREEN}  ✓${NC} Detected IP: ${MY_IP}"
      else
        echo -e "${YELLOW}  Couldn't detect IP. Enter manually:${NC}"
        read -p "  CIDR: " ALLOW_CIDR
      fi
      ;;
    2) ALLOW_CIDR="0.0.0.0/0" ;;
    3) read -p "  CIDR range: " ALLOW_CIDR ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
  esac
fi
echo -e "${GREEN}  ✓${NC} Firewall CIDR: ${ALLOW_CIDR}"

# --- Summary ---
echo ""
echo -e "${BLUE}▸ Deployment summary:${NC}"
echo -e "  Instance:     ${INSTANCE_NAME}"
echo -e "  Project:      ${GCP_PROJECT}"
echo -e "  Zone:         ${ZONE}"
echo -e "  Machine:      ${MACHINE_TYPE}"
echo -e "  Disk:         ${DISK_SIZE}"
echo -e "  Dolt port:    ${DOLT_PORT}"
echo -e "  Dolt user:    ${DOLT_USER}"
echo -e "  Firewall:     ${ALLOW_CIDR} → :${DOLT_PORT}"
echo ""
echo -e "  Estimated cost: ${YELLOW}~\$7/month${NC} (e2-micro + 10GB disk + static IP)"
echo ""
read -p "  Proceed? [Y/n] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "Aborted."
  exit 0
fi

# --- Reserve static IP ---
echo -e "${BLUE}▸${NC} Reserving static IP..."
if gcloud compute addresses describe "${INSTANCE_NAME}-ip" --region="${ZONE%-*}" --project="$GCP_PROJECT" &>/dev/null; then
  echo -e "${GREEN}  ✓${NC} Static IP already reserved"
else
  gcloud compute addresses create "${INSTANCE_NAME}-ip" \
    --region="${ZONE%-*}" \
    --project="$GCP_PROJECT" \
    --quiet
  echo -e "${GREEN}  ✓${NC} Static IP reserved"
fi
STATIC_IP=$(gcloud compute addresses describe "${INSTANCE_NAME}-ip" \
  --region="${ZONE%-*}" --project="$GCP_PROJECT" \
  --format="value(address)")
echo -e "  IP: ${YELLOW}${STATIC_IP}${NC}"

# --- Startup script (runs on first boot and reboots) ---
STARTUP_SCRIPT=$(cat <<'STARTUP'
#!/bin/bash
set -e

# Only install on first boot
if [[ ! -f /opt/dolt-installed ]]; then
  echo "[beads-setup] Installing Dolt..."

  # Install Dolt
  curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash

  # Create beads user and data directory
  useradd --system --create-home --shell /bin/false dolt || true
  mkdir -p /var/lib/dolt/data
  chown -R dolt:dolt /var/lib/dolt

  # Initialize Dolt database
  sudo -u dolt bash -c 'cd /var/lib/dolt/data && dolt init --name "beads-server" --email "beads@localhost"'

  # Create systemd service
  cat > /etc/systemd/system/dolt.service <<EOF
[Unit]
Description=Dolt SQL Server
After=network.target

[Service]
Type=simple
User=dolt
WorkingDirectory=/var/lib/dolt/data
ExecStart=/usr/local/bin/dolt sql-server \
  --host 0.0.0.0 \
  --port DOLT_PORT_PLACEHOLDER \
  --user DOLT_USER_PLACEHOLDER \
  --password DOLT_PASSWORD_PLACEHOLDER
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable dolt

  touch /opt/dolt-installed
  echo "[beads-setup] Installation complete"
fi

# Always start the service (handles reboots)
systemctl start dolt
echo "[beads-setup] Dolt server running on port DOLT_PORT_PLACEHOLDER"
STARTUP
)

# Substitute placeholders
STARTUP_SCRIPT="${STARTUP_SCRIPT//DOLT_PORT_PLACEHOLDER/$DOLT_PORT}"
STARTUP_SCRIPT="${STARTUP_SCRIPT//DOLT_USER_PLACEHOLDER/$DOLT_USER}"
STARTUP_SCRIPT="${STARTUP_SCRIPT//DOLT_PASSWORD_PLACEHOLDER/$DOLT_PASSWORD}"

# --- Create VM ---
echo -e "${BLUE}▸${NC} Creating VM..."
if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --project="$GCP_PROJECT" &>/dev/null; then
  echo -e "${YELLOW}  ⊙${NC} Instance already exists — skipping creation"
else
  gcloud compute instances create "$INSTANCE_NAME" \
    --project="$GCP_PROJECT" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --boot-disk-size="$DISK_SIZE" \
    --boot-disk-type=pd-standard \
    --address="$STATIC_IP" \
    --tags="beads-server" \
    --metadata=startup-script="$STARTUP_SCRIPT" \
    --quiet
  echo -e "${GREEN}  ✓${NC} VM created"
fi

# --- Firewall rule ---
echo -e "${BLUE}▸${NC} Configuring firewall..."
RULE_NAME="allow-beads-dolt"
if gcloud compute firewall-rules describe "$RULE_NAME" --project="$GCP_PROJECT" &>/dev/null; then
  # Update existing rule
  gcloud compute firewall-rules update "$RULE_NAME" \
    --project="$GCP_PROJECT" \
    --source-ranges="$ALLOW_CIDR" \
    --quiet
  echo -e "${GREEN}  ✓${NC} Firewall rule updated"
else
  gcloud compute firewall-rules create "$RULE_NAME" \
    --project="$GCP_PROJECT" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:${DOLT_PORT} \
    --source-ranges="$ALLOW_CIDR" \
    --target-tags="beads-server" \
    --quiet
  echo -e "${GREEN}  ✓${NC} Firewall rule created"
fi

# --- Output ---
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  BEADS Server Deployed${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Server:   ${YELLOW}${STATIC_IP}:${DOLT_PORT}${NC}"
echo -e "  User:     ${DOLT_USER}"
echo -e "  Password: ${DOLT_PASSWORD}"
echo ""
echo -e "  ${BLUE}Add to your project's quality-config.json:${NC}"
echo ""
echo -e '  "beads": {'
echo -e '    "enabled": true,'
echo -e '    "server": {'
echo -e "      \"host\": \"${STATIC_IP}\","
echo -e "      \"port\": ${DOLT_PORT}"
echo -e '    }'
echo -e '  }'
echo ""
echo -e "  ${BLUE}Then add your user to ~/.config/beads/credentials:${NC}"
echo -e "  [${STATIC_IP}:${DOLT_PORT}]"
echo -e "  user = ${DOLT_USER}"
echo ""
echo -e "  ${BLUE}Set the password as an environment variable:${NC}"
echo -e "  export BEADS_DOLT_PASSWORD=${DOLT_PASSWORD}"
echo ""
echo -e "  ${YELLOW}Note:${NC} Dolt takes ~60 seconds to install on first boot."
echo -e "  Check progress: gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE} -- journalctl -u dolt -f"
echo ""

# --- Save connection info for teardown and reference ---
cat > "$(dirname "$0")/.beads-server-info" <<EOF
GCP_PROJECT=${GCP_PROJECT}
ZONE=${ZONE}
INSTANCE_NAME=${INSTANCE_NAME}
STATIC_IP=${STATIC_IP}
DOLT_PORT=${DOLT_PORT}
DOLT_USER=${DOLT_USER}
EOF
echo -e "  Connection info saved to ${YELLOW}deploy/beads-server/.beads-server-info${NC}"
echo -e "  ${RED}Do NOT commit this file${NC} (contains server details)"
