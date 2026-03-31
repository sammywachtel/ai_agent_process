#!/usr/bin/env bash
#
# AI Agent Process Template - Installation Script
#
# Usage:
#   ./install.sh <target>              # Install from source to target
#   cd <target>; <source>/install.sh   # Install to current directory
#   cd <target>; <source>/install.sh . # Install to current directory (explicit)
#
# This script:
# - Updates .claude/commands/ with command scripts
# - Installs/updates .agent_process/ template files
# - Preserves existing .agent_process/work/ directory
# - Makes hook scripts executable

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ensure ~/.config/beads/credentials exists with header template
ensure_beads_credentials() {
  local creds_file="${HOME}/.config/beads/credentials"
  mkdir -p "${HOME}/.config/beads"
  if [[ ! -f "$creds_file" ]]; then
    cat > "$creds_file" << 'CREDS_TEMPLATE'
# BEADS Dolt Server Credentials
#
# Each section is [host:port] matching the beads.server config in a project's
# quality-config.json. Projects only read the section matching their configured host.
#
# In Docker containers, 127.0.0.1/localhost are rewritten to host.docker.internal
# automatically — the script checks both the rewritten and original keys.
#
# To add a new server:
#   [hostname:port]
#   user = your_username
#   password = your_password_here
#
# Examples:
#   [127.0.0.1:3307]          — local Dolt (personal projects)
#   [beads.company.com:3307]  — shared team server (work projects)
#   [10.0.1.50:3307]          — office network server
#
# This file is chmod 600. Do not commit it to any repo.
CREDS_TEMPLATE
    chmod 600 "$creds_file"
  fi
}

# Save user/password to credentials file (idempotent, preserves header + existing entries)
save_beads_credential() {
  local host="$1" port="$2" password="$3" user="${4:-}"
  ensure_beads_credentials
  python3 -c "
import os, re

path = os.path.expanduser('~/.config/beads/credentials')
content = open(path).read() if os.path.exists(path) else ''

# Preserve comment header (everything before first [section])
header = ''
body = content
first_section = re.search(r'^\[', content, re.MULTILINE)
if first_section:
    header = content[:first_section.start()]
    body = content[first_section.start():]
elif content.startswith('#'):
    header = content
    body = ''

# Parse sections from body
import configparser, io
cp = configparser.ConfigParser()
cp.read_string(body)

section = '${host}:${port}'
if not cp.has_section(section):
    cp.add_section(section)
if '${password}':
    cp.set(section, 'password', '${password}')
if '${user}':
    cp.set(section, 'user', '${user}')

# Write header + sections
with open(path, 'w') as f:
    f.write(header)
    cp.write(f)
os.chmod(path, 0o600)
" 2>/dev/null
}

# Determine source directory (where this script lives)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine target directory
if [[ $# -eq 0 ]]; then
  # No arguments - target is current directory
  TARGET_DIR="$(pwd)"
elif [[ "$1" == "." ]]; then
  # Explicit current directory
  TARGET_DIR="$(pwd)"
else
  # Target directory specified
  TARGET_DIR="$(cd "$1" && pwd)"
fi

# Validate that we're not installing to the source directory
if [[ "$SOURCE_DIR" == "$TARGET_DIR" ]]; then
  echo -e "${RED}Error: Cannot install to the source directory itself${NC}"
  echo "Source: $SOURCE_DIR"
  echo "Target: $TARGET_DIR"
  exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  AI Agent Process Template - Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Source: ${GREEN}$SOURCE_DIR${NC}"
echo -e "  Target: ${GREEN}$TARGET_DIR${NC}"

# Check if .agent_process is a symlink
AGENT_PROCESS_DIR="$TARGET_DIR/.agent_process"
AGENT_PROCESS_IS_SYMLINK=false

if [[ -L "$AGENT_PROCESS_DIR" ]]; then
  AGENT_PROCESS_IS_SYMLINK=true
  SYMLINK_TARGET="$(readlink "$AGENT_PROCESS_DIR")"
  echo -e "  ${YELLOW}Note:${NC} .agent_process is a symlink → ${GREEN}$SYMLINK_TARGET${NC}"
fi
echo ""

# Verify source directory has required structure
if [[ ! -d "$SOURCE_DIR/claude/commands" ]]; then
  echo -e "${RED}Error: Source directory missing claude/commands/${NC}"
  echo "Are you running this from the AI Agent Process template directory?"
  exit 1
fi

# Create target directories
echo -e "${BLUE}▸${NC} Creating directory structure..."

mkdir -p "$TARGET_DIR/.claude/commands"

# Handle .agent_process directory creation (respecting symlinks)
if [[ "$AGENT_PROCESS_IS_SYMLINK" == true ]]; then
  echo -e "${YELLOW}  ⊙${NC} Using existing symlink for .agent_process/"
  # Ensure subdirectories exist within the symlink target
  mkdir -p "$AGENT_PROCESS_DIR/orchestration"
  mkdir -p "$AGENT_PROCESS_DIR/process"
  mkdir -p "$AGENT_PROCESS_DIR/scripts/after_edit"
  mkdir -p "$AGENT_PROCESS_DIR/templates"
  mkdir -p "$AGENT_PROCESS_DIR/requirements_docs"
  mkdir -p "$AGENT_PROCESS_DIR/claude/commands"
else
  mkdir -p "$AGENT_PROCESS_DIR/orchestration"
  mkdir -p "$AGENT_PROCESS_DIR/process"
  mkdir -p "$AGENT_PROCESS_DIR/scripts/after_edit"
  mkdir -p "$AGENT_PROCESS_DIR/templates"
  mkdir -p "$AGENT_PROCESS_DIR/requirements_docs"
  mkdir -p "$AGENT_PROCESS_DIR/claude/commands"
fi

# Only create work/ if it doesn't exist (preserve existing work)
if [[ ! -d "$AGENT_PROCESS_DIR/work" ]]; then
  mkdir -p "$AGENT_PROCESS_DIR/work"
  echo -e "${GREEN}  ✓${NC} Created .agent_process/work/ directory"
else
  echo -e "${YELLOW}  ⊙${NC} Preserving existing .agent_process/work/ directory"
fi

# Knowledge base directory — .beads/knowledge/ when BEADS enabled, .agent_process/knowledge/ as fallback
# Both are created; the orchestrator/agents pick the right one at runtime
KB_FILES="patterns gotchas decisions anti-patterns"
KB_FILES_EXTENDED="codebase-facts api-behaviors"  # metaswarm-compatible extras

# Always ensure .agent_process/knowledge/ exists (fallback when BEADS disabled)
if [[ ! -d "$AGENT_PROCESS_DIR/knowledge" ]]; then
  mkdir -p "$AGENT_PROCESS_DIR/knowledge"
  for kb_file in $KB_FILES; do
    if [[ ! -f "$AGENT_PROCESS_DIR/knowledge/${kb_file}.jsonl" ]]; then
      echo "# Schema: ${kb_file}.jsonl — see process/knowledge-base.md for format" > "$AGENT_PROCESS_DIR/knowledge/${kb_file}.jsonl"
    fi
  done
  echo -e "${GREEN}  ✓${NC} Created .agent_process/knowledge/ (fallback)"
else
  echo -e "${YELLOW}  ⊙${NC} Preserving existing .agent_process/knowledge/"
fi

# Create .beads/knowledge/ for BEADS-managed knowledge (metaswarm-compatible)
if [[ ! -d "$TARGET_DIR/.beads/knowledge" ]]; then
  mkdir -p "$TARGET_DIR/.beads/knowledge"
  for kb_file in $KB_FILES $KB_FILES_EXTENDED; do
    if [[ ! -f "$TARGET_DIR/.beads/knowledge/${kb_file}.jsonl" ]]; then
      echo "# Schema: ${kb_file}.jsonl — metaswarm-compatible. See process/knowledge-base.md" > "$TARGET_DIR/.beads/knowledge/${kb_file}.jsonl"
    fi
  done
  echo -e "${GREEN}  ✓${NC} Created .beads/knowledge/ (primary, metaswarm-compatible)"
else
  echo -e "${YELLOW}  ⊙${NC} Preserving existing .beads/knowledge/"
fi

# Migrate legacy .agent_process/knowledge/ entries → .beads/knowledge/ (idempotent)
# Uses scripts/migrate-knowledge.py — same script users can run manually
if [[ -d "$AGENT_PROCESS_DIR/knowledge" && -d "$TARGET_DIR/.beads/knowledge" ]]; then
  MIGRATED=$(python3 "$SOURCE_DIR/scripts/migrate-knowledge.py" --src "$AGENT_PROCESS_DIR/knowledge" --dst "$TARGET_DIR/.beads/knowledge" -q 2>/dev/null || echo "0")
  if [[ "$MIGRATED" -gt 0 ]]; then
    echo -e "${GREEN}  ✓${NC} Migrated ${MIGRATED} knowledge entries from .agent_process/knowledge/ → .beads/knowledge/"
  fi
fi

# Ensure quality-config.json exists (seed from template if missing)
QUALITY_CONFIG_FRESH=false
if [[ ! -f "$AGENT_PROCESS_DIR/quality-config.json" ]]; then
  cp "$SOURCE_DIR/quality-config.json" "$AGENT_PROCESS_DIR/quality-config.json"
  QUALITY_CONFIG_FRESH=true
fi

# ─── Feature Selection ───────────────────────────────────────────────
# Always prompt — lets users review and change settings on every install.
# Default is enabled (Enter = yes) for all features.
echo ""
echo -e "${BLUE}▸${NC} Feature configuration..."
echo -e "  Configure which quality gates are active. Press Enter to accept the default."
echo ""

# Read current values from config (or use defaults)
read_feature() {
  local feature="$1" default="$2"
  python3 -c "
import json
try:
    cfg = json.load(open('$AGENT_PROCESS_DIR/quality-config.json'))
    parts = '$feature'.split('.')
    val = cfg
    for p in parts:
        val = val.get(p, {})
    if isinstance(val, bool):
        print('yes' if val else 'no')
    else:
        print('$default')
except:
    print('$default')
" 2>/dev/null || echo "$default"
}

prompt_feature() {
  local label="$1" desc="$2" feature="$3" default="$4"
  local current
  current=$(read_feature "$feature" "$default")
  local hint="Y/n"
  [[ "$current" == "no" ]] && hint="y/N"
  read -p "  $label ($desc) [$hint]: " -n 1 -r
  echo "" >&2
  if [[ -z "$REPLY" ]]; then
    # Enter pressed — keep current/default
    echo "$current"
  elif [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

FEAT_PREFLIGHT=$(prompt_feature "Pre-flight checks" "session recovery, branch check, git context" "pre_flight.enabled" "yes")
FEAT_KNOWLEDGE=$(prompt_feature "Knowledge base" "patterns, gotchas, decisions across iterations" "knowledge_base.enabled" "yes")
FEAT_ADVERSARIAL=$(prompt_feature "Adversarial review" "fresh-agent criterion verification" "adversarial_review.enabled" "yes")
FEAT_DECOMPOSITION=$(prompt_feature "Work unit decomposition" "DAG-based parallel execution for multi-domain scopes" "work_unit_decomposition.enabled" "yes")
FEAT_DESIGN_REVIEW=$(prompt_feature "Design review gate" "multi-reviewer plan assessment for complex scopes" "design_review.enabled" "no")
FEAT_BEADS=$(prompt_feature "BEADS" "git-native durable state tracking via Dolt" "beads.enabled" "yes")
FEAT_PR_SHEPHERD=$(prompt_feature "PR shepherd" "post-PR agent monitoring CI and reviews" "pr_shepherd.enabled" "yes")
FEAT_METASWARM=$(prompt_feature "Metaswarm integration" "brainstorming, design review, knowledge priming" "metaswarm.enabled" "no")

# Write all selections to quality-config.json
python3 -c "
import json
path = '$AGENT_PROCESS_DIR/quality-config.json'
try:
    cfg = json.load(open(path))
except:
    cfg = {}

def to_bool(s): return s == 'yes'

cfg.setdefault('pre_flight', {})['enabled'] = to_bool('$FEAT_PREFLIGHT')
cfg.setdefault('knowledge_base', {})['enabled'] = to_bool('$FEAT_KNOWLEDGE')
cfg.setdefault('adversarial_review', {})['enabled'] = to_bool('$FEAT_ADVERSARIAL')
cfg.setdefault('work_unit_decomposition', {})['enabled'] = to_bool('$FEAT_DECOMPOSITION')
cfg.setdefault('design_review', {})['enabled'] = to_bool('$FEAT_DESIGN_REVIEW')
cfg.setdefault('beads', {})['enabled'] = to_bool('$FEAT_BEADS')
cfg['beads']['_user_configured'] = True
cfg.setdefault('pr_shepherd', {})['enabled'] = to_bool('$FEAT_PR_SHEPHERD')
cfg.setdefault('metaswarm', {})['enabled'] = to_bool('$FEAT_METASWARM')
cfg['metaswarm']['_user_configured'] = True

json.dump(cfg, open(path, 'w'), indent=2)
print('OK')
" 2>/dev/null

echo ""
echo -e "${GREEN}  ✓${NC} Feature configuration saved to quality-config.json"

# ─── BEADS Setup (if enabled) ────────────────────────────────────────
if [[ "$FEAT_BEADS" == "yes" ]]; then
  echo ""
  echo -e "${BLUE}▸${NC} BEADS durable state tracking..."

  # --- Phase 1: Discover Dolt endpoints ---
  # Check for local binary, Docker container, and tunnel credentials.
  # Always present a menu — local binary and Docker are always shown,
  # tunnel appears when credentials exist.
  DOLT_AVAILABLE=false
  DOLT_HOST=""
  DOLT_PORT="3307"
  DOLT_USER="root"

  # Check 1: local dolt binary
  HAS_LOCAL_DOLT=false
  LOCAL_DOLT_RUNNING=false
  if command -v dolt &>/dev/null; then
    HAS_LOCAL_DOLT=true
    nc -z 127.0.0.1 3307 2>/dev/null && LOCAL_DOLT_RUNNING=true
  fi

  # Check 2: Docker container (beads-dolt-server)
  HAS_DOCKER=false
  DOCKER_DOLT_RUNNING=false
  DOCKER_DOLT_EXISTS=false
  if command -v docker &>/dev/null; then
    HAS_DOCKER=true
    # Check if our named container is running
    if docker ps --filter "name=beads-dolt-server" --format '{{.Names}}' 2>/dev/null | grep -q beads-dolt-server; then
      DOCKER_DOLT_RUNNING=true
      DOCKER_DOLT_EXISTS=true
    # Check if container exists but is stopped
    elif docker ps -a --filter "name=beads-dolt-server" --format '{{.Names}}' 2>/dev/null | grep -q beads-dolt-server; then
      DOCKER_DOLT_EXISTS=true
    fi
  fi

  # Check 3: tunnel credentials in ~/.config/beads/credentials (written by setup-developer.sh)
  HAS_TUNNEL=false
  TUNNEL_PORT=""
  TUNNEL_USER=""
  TUNNEL_CONNECTED=false
  CREDS_FILE="${HOME}/.config/beads/credentials"
  if [[ -f "$CREDS_FILE" ]]; then
    TUNNEL_PORT=$(python3 -c "
import configparser, os
cp = configparser.ConfigParser()
cp.read(os.path.expanduser('~/.config/beads/credentials'))
# Find localhost entries that aren't the default 3307 (those are tunnel endpoints)
for s in cp.sections():
    if s.startswith('127.0.0.1:') and not s.endswith(':3307'):
        print(s.split(':')[1])
        break
" 2>/dev/null) || true
    if [[ -n "$TUNNEL_PORT" ]]; then
      HAS_TUNNEL=true
      # Derive username from credentials or gcloud identity
      TUNNEL_USER=$(python3 -c "
import configparser, os
cp = configparser.ConfigParser()
cp.read(os.path.expanduser('~/.config/beads/credentials'))
key = '127.0.0.1:${TUNNEL_PORT}'
if cp.has_section(key) and cp.has_option(key, 'user'):
    print(cp.get(key, 'user'))
" 2>/dev/null) || true
      if [[ -z "$TUNNEL_USER" ]]; then
        GCLOUD_EMAIL=$(gcloud config get-value account 2>/dev/null || true)
        if [[ -n "$GCLOUD_EMAIL" ]]; then
          TUNNEL_USER="${GCLOUD_EMAIL%%@*}"
          TUNNEL_USER="${TUNNEL_USER%%.*}"
        fi
      fi
      nc -z 127.0.0.1 "$TUNNEL_PORT" 2>/dev/null && TUNNEL_CONNECTED=true
    fi
  fi

  # --- Phase 2: Always show a menu ---
  echo ""
  echo -e "  Dolt server — which would you like to use?"
  MENU_IDX=0
  MENU_MAP=()

  # Option: local Dolt binary (always shown)
  MENU_IDX=$((MENU_IDX + 1))
  if [[ "$HAS_LOCAL_DOLT" == true ]]; then
    if [[ "$LOCAL_DOLT_RUNNING" == true ]]; then
      echo -e "    ${MENU_IDX}) Local Dolt binary ${GREEN}(installed, running on :3307)${NC}"
    else
      echo -e "    ${MENU_IDX}) Local Dolt binary ${YELLOW}(installed, not running)${NC}"
    fi
  else
    echo -e "    ${MENU_IDX}) Local Dolt binary ${RED}(not installed)${NC}"
  fi
  MENU_MAP+=("local")

  # Option: Docker Dolt (always shown)
  MENU_IDX=$((MENU_IDX + 1))
  if [[ "$DOCKER_DOLT_RUNNING" == true ]]; then
    echo -e "    ${MENU_IDX}) Local Dolt via Docker ${GREEN}(running on :3307)${NC}"
  elif [[ "$DOCKER_DOLT_EXISTS" == true ]]; then
    echo -e "    ${MENU_IDX}) Local Dolt via Docker ${YELLOW}(container stopped)${NC}"
  elif [[ "$HAS_DOCKER" == true ]]; then
    echo -e "    ${MENU_IDX}) Local Dolt via Docker ${YELLOW}(not yet installed)${NC}"
  else
    echo -e "    ${MENU_IDX}) Local Dolt via Docker ${RED}(Docker not found)${NC}"
  fi
  MENU_MAP+=("docker")

  # Option: IAP tunnel (only when credentials exist)
  if [[ "$HAS_TUNNEL" == true ]]; then
    MENU_IDX=$((MENU_IDX + 1))
    if [[ "$TUNNEL_CONNECTED" == true ]]; then
      echo -e "    ${MENU_IDX}) Remote Dolt via IAP tunnel ${GREEN}(connected, :${TUNNEL_PORT})${NC}"
    else
      echo -e "    ${MENU_IDX}) Remote Dolt via IAP tunnel ${YELLOW}(credentials found, not connected)${NC}"
    fi
    MENU_MAP+=("tunnel")
  fi

  # Option: custom host:port (always shown)
  MENU_IDX=$((MENU_IDX + 1))
  echo -e "    ${MENU_IDX}) Enter different host:port"
  MENU_MAP+=("custom")

  echo ""
  read -p "  Select [1-${MENU_IDX}]: " -n 1 -r DOLT_CHOICE
  echo ""

  DOLT_CHOICE="${DOLT_CHOICE:-1}"
  CHOICE_IDX=$((DOLT_CHOICE - 1))

  if [[ "$CHOICE_IDX" -ge 0 && "$CHOICE_IDX" -lt "${#MENU_MAP[@]}" ]]; then
    case "${MENU_MAP[$CHOICE_IDX]}" in

      local)
        if [[ "$HAS_LOCAL_DOLT" != true ]]; then
          echo ""
          echo -e "${YELLOW}  Dolt binary is not installed.${NC}"
          echo -e "  Dolt is included with BEADS. Install BEADS first, then re-run:"
          echo -e "    ${GREEN}go install github.com/sammywachtel/beads/cmd/bd@latest${NC}"
          echo -e "    ${GREEN}brew install dolt${NC}  (or see https://docs.dolthub.com/introduction/installation)"
          echo -e "    Then re-run: ${GREEN}$0${NC}"
          # Don't exit — fall through to DOLT_AVAILABLE=false handling
        else
          DOLT_AVAILABLE=true
          DOLT_HOST="127.0.0.1"
          DOLT_PORT="3307"
          DOLT_USER="root"
          if [[ "$LOCAL_DOLT_RUNNING" == true ]]; then
            echo -e "${GREEN}  ✓${NC} Using local Dolt (localhost:3307)"
          else
            echo -e "${GREEN}  ✓${NC} Using local Dolt (localhost:3307) — start it with: ${YELLOW}dolt sql-server${NC}"
          fi
        fi
        ;;

      docker)
        if [[ "$HAS_DOCKER" != true ]]; then
          echo ""
          echo -e "${RED}  Docker is not installed.${NC}"
          echo -e "  Install Docker first: ${GREEN}https://docs.docker.com/get-docker/${NC}"
          echo -e "  Then re-run: ${GREEN}$0${NC}"
        elif [[ "$DOCKER_DOLT_RUNNING" == true ]]; then
          # Already running — just use it
          DOLT_AVAILABLE=true
          DOLT_HOST="127.0.0.1"
          DOLT_PORT="3307"
          DOLT_USER="root"
          echo -e "${GREEN}  ✓${NC} Using Docker Dolt (localhost:3307)"
        elif [[ "$DOCKER_DOLT_EXISTS" == true ]]; then
          # Container exists but stopped — start it
          echo -e "  Starting stopped beads-dolt-server container..."
          if docker start beads-dolt-server 2>/dev/null; then
            DOLT_AVAILABLE=true
            DOLT_HOST="127.0.0.1"
            DOLT_PORT="3307"
            DOLT_USER="root"
            echo -e "${GREEN}  ✓${NC} Docker Dolt restarted (localhost:3307)"
          else
            echo -e "${RED}  Failed to start container.${NC} Try: docker start beads-dolt-server"
          fi
        else
          # No container yet — create one
          DOLT_DATA_DIR="${HOME}/.dolt-server/data"
          DOLT_CFG_DIR="${HOME}/.dolt-server/config"
          mkdir -p "$DOLT_DATA_DIR" "$DOLT_CFG_DIR"

          # If the volume already has a privileges.db, DOLT_ROOT_PASSWORD is ignored —
          # Dolt only seeds that file on first-ever init. We must use whatever password
          # the volume was originally created with, or we'll get access denied.
          HAS_EXISTING_DATA=false
          [[ -f "$DOLT_DATA_DIR/.doltcfg/privileges.db" ]] && HAS_EXISTING_DATA=true

          if [[ "$HAS_EXISTING_DATA" == true ]]; then
            # Try to find a working password — check all localhost/docker entries
            EXISTING_PASS=$(python3 -c "
import configparser, os
cp = configparser.ConfigParser()
cp.read(os.path.expanduser('~/.config/beads/credentials'))
# Check both keys — the password may have been saved under either
for key in ['127.0.0.1:3307', 'host.docker.internal:3307']:
    if cp.has_section(key) and cp.has_option(key, 'password'):
        print(cp.get(key, 'password'))
        break
" 2>/dev/null) || true
            if [[ -n "$EXISTING_PASS" ]]; then
              DOLT_PASS="$EXISTING_PASS"
              echo -e "  Existing Dolt data found — reusing saved credentials"
            else
              echo -e "${YELLOW}  ⚠ Existing Dolt data found but no saved password.${NC}"
              echo -e "  If you know the root password, update ~/.config/beads/credentials"
              echo -e "  Or remove ${DOLT_DATA_DIR} to start fresh."
              DOLT_PASS=""
            fi
          else
            DOLT_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 16)
          fi

          if [[ -z "$DOLT_PASS" ]]; then
            # No password available — can't start the container usefully
            echo -e "${RED}  Cannot start Docker Dolt without a password.${NC}"
          else

          echo -e "  Starting Dolt SQL server via Docker..."
          docker run -d \
            --name beads-dolt-server \
            --restart unless-stopped \
            -e DOLT_ROOT_HOST='%' \
            -e DOLT_ROOT_PASSWORD="$DOLT_PASS" \
            -p 3307:3306 \
            -v "$DOLT_DATA_DIR":/var/lib/dolt \
            -v "$DOLT_CFG_DIR":/etc/dolt/servercfg.d \
            dolthub/dolt-sql-server:latest \
            2>/dev/null
          if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}  ✓${NC} Dolt server running in Docker (port 3307)"
            echo -e "  Data persisted at: ${YELLOW}${DOLT_DATA_DIR}${NC}"
            DOLT_AVAILABLE=true
            DOLT_HOST="127.0.0.1"
            DOLT_PORT="3307"
            DOLT_USER="root"
            # Save under both keys — bd connects via 127.0.0.1, but containers
            # rewrite to host.docker.internal. Keep them in sync.
            save_beads_credential "127.0.0.1" "3307" "$DOLT_PASS"
            save_beads_credential "host.docker.internal" "3307" "$DOLT_PASS"
            echo -e "${GREEN}  ✓${NC} Credentials saved to ~/.config/beads/credentials"
          else
            echo -e "${YELLOW}  ⊙${NC} Docker failed to start Dolt."
            echo -e "  Try manually: ${GREEN}docker run -d --name beads-dolt-server -p 3307:3306 dolthub/dolt-sql-server:latest${NC}"
          fi

          fi  # end password-available guard
        fi
        ;;

      tunnel)
        DOLT_HOST="127.0.0.1"
        DOLT_PORT="$TUNNEL_PORT"
        DOLT_USER="${TUNNEL_USER:-root}"
        if [[ "$TUNNEL_CONNECTED" == true ]]; then
          DOLT_AVAILABLE=true
          echo -e "${GREEN}  ✓${NC} Using IAP tunnel (localhost:${TUNNEL_PORT})"
        else
          echo -e "${YELLOW}  ⚠${NC} Tunnel credentials found but port ${TUNNEL_PORT} is not connected."
          echo -e "  Start the tunnel, then re-run: ${GREEN}$0${NC}"
          DOLT_AVAILABLE=true
          echo -e "${GREEN}  ✓${NC} Configured for IAP tunnel (localhost:${TUNNEL_PORT}) — will connect when tunnel is active"
        fi
        # Ensure user is saved to credentials (may have been derived from gcloud)
        if [[ -n "$DOLT_USER" && "$DOLT_USER" != "root" ]]; then
          save_beads_credential "$DOLT_HOST" "$DOLT_PORT" "" "$DOLT_USER"
        fi
        ;;

      custom)
        read -p "  Dolt server host: " CUSTOM_HOST
        read -p "  Dolt server port [3307]: " CUSTOM_PORT
        CUSTOM_PORT="${CUSTOM_PORT:-3307}"
        read -p "  Dolt user [root]: " CUSTOM_USER
        CUSTOM_USER="${CUSTOM_USER:-root}"
        if nc -z "$CUSTOM_HOST" "$CUSTOM_PORT" 2>/dev/null; then
          echo -e "${GREEN}  ✓${NC} Connected to ${CUSTOM_HOST}:${CUSTOM_PORT}"
          DOLT_AVAILABLE=true
          DOLT_HOST="$CUSTOM_HOST"
          DOLT_PORT="$CUSTOM_PORT"
          DOLT_USER="$CUSTOM_USER"
        else
          echo -e "${RED}  Cannot reach ${CUSTOM_HOST}:${CUSTOM_PORT}${NC}"
        fi
        ;;
    esac
  fi

  # Write server config to quality-config.json (host + port only — shared across team).
  # User is per-developer and stored in ~/.config/beads/credentials instead.
  if [[ "$DOLT_AVAILABLE" == true && -n "$DOLT_HOST" ]]; then
    python3 -c "
import json
path = '$AGENT_PROCESS_DIR/quality-config.json'
try:
    cfg = json.load(open(path))
    server = cfg.setdefault('beads', {}).setdefault('server', {})
    server['host'] = '$DOLT_HOST'
    server['port'] = int('$DOLT_PORT')
    server.pop('user', None)  # user lives in ~/.config/beads/credentials now
    json.dump(cfg, open(path, 'w'), indent=2)
except:
    pass
" 2>/dev/null
    # Save user to credentials file (per-developer, not committed)
    if [[ -n "$DOLT_USER" && "$DOLT_USER" != "root" ]]; then
      save_beads_credential "$DOLT_HOST" "$DOLT_PORT" "" "$DOLT_USER"
    fi
  fi

  # Install BEADS CLI (bd) if Dolt is available but bd is not.
  # Our fork's go.mod declares module as steveyegge/beads (upstream path),
  # so `go install github.com/sammywachtel/...` won't resolve. Clone and build.
  if [[ "$DOLT_AVAILABLE" == true ]] && ! command -v bd &>/dev/null; then
    echo -e "  Installing BEADS CLI (bd)..."
    BEADS_INSTALLED=false
    if command -v go &>/dev/null && command -v git &>/dev/null; then
      BD_CLONE_DIR="${TMPDIR:-/tmp}/beads-install-$$"
      if git clone --depth 1 --quiet https://github.com/sammywachtel/beads.git "$BD_CLONE_DIR" 2>/dev/null; then
        if (cd "$BD_CLONE_DIR" && go install ./cmd/bd 2>/dev/null); then
          BEADS_INSTALLED=true
          echo -e "${GREEN}  ✓${NC} Installed BEADS CLI from fork (go build)"
        fi
        rm -rf "$BD_CLONE_DIR"
      fi
    fi
    if [[ "$BEADS_INSTALLED" == false ]]; then
      echo -e "${YELLOW}  ⊙${NC} BEADS CLI install failed."
      echo -e "    Install manually: git clone https://github.com/sammywachtel/beads.git && cd beads && go install ./cmd/bd"
    fi
  elif [[ "$DOLT_AVAILABLE" == true ]]; then
    echo -e "${GREEN}  ✓${NC} BEADS ready (Dolt + bd available)"
  fi
fi


# Initialize BEADS database if bd is available and enabled.
# Check for metadata.json (not just .beads/) since knowledge migration creates .beads/knowledge/ early.
# Works with both local Dolt (command -v dolt) and remote/Docker Dolt (beads.server in config).
if command -v bd &>/dev/null && [[ ! -f "${TARGET_DIR}/.beads/metadata.json" ]]; then
  # Read config to check enabled + get server connection (host/port from config, user from credentials)
  BEADS_INIT_INFO=$(python3 -c "
import json
try:
    cfg = json.load(open('$AGENT_PROCESS_DIR/quality-config.json'))
    b = cfg.get('beads', {})
    if not b.get('enabled', False):
        print('disabled')
    else:
        server = b.get('server', {})
        host = server.get('host', '')
        port = server.get('port', '')
        print(f'enabled|{host}|{port}')
except:
    print('disabled')
" 2>/dev/null)

  if [[ "$BEADS_INIT_INFO" != "disabled" ]]; then
    # Parse server config (host + port from quality-config.json)
    IFS='|' read -r _ BHOST BPORT <<< "$BEADS_INIT_INFO"

    # Export env vars so bd init can connect to the right server
    [[ -n "$BHOST" ]] && export BEADS_DOLT_SERVER_HOST="$BHOST"
    [[ -n "$BPORT" ]] && export BEADS_DOLT_SERVER_PORT="$BPORT"

    # Load user + password from credentials file (per-developer, not committed)
    CREDS_FILE="${HOME}/.config/beads/credentials"
    BUSER=""
    if [[ -f "$CREDS_FILE" && -n "$BHOST" ]]; then
      read -r BUSER BPASS <<< "$(python3 -c "
import configparser, os
cp = configparser.ConfigParser()
cp.read(os.path.expanduser('~/.config/beads/credentials'))
key = '${BHOST}:${BPORT:-3307}'
user = ''
password = ''
if cp.has_section(key):
    user = cp.get(key, 'user', fallback='')
    password = cp.get(key, 'password', fallback='')
print(f'{user} {password}')
" 2>/dev/null)" || true
      [[ -n "${BUSER:-}" ]] && export BEADS_DOLT_SERVER_USER="$BUSER"
      [[ -n "${BPASS:-}" ]] && export BEADS_DOLT_PASSWORD="$BPASS"
    fi

    # Check we can reach Dolt somehow (local binary OR remote server)
    DOLT_REACHABLE=false
    if [[ -n "$BHOST" ]]; then
      # Remote server configured — check TCP connectivity
      nc -z "$BHOST" "${BPORT:-3307}" 2>/dev/null && DOLT_REACHABLE=true
    elif command -v dolt &>/dev/null; then
      # Local Dolt binary
      DOLT_REACHABLE=true
    fi

    # Create .beads/.env with password for init-time authentication.
    # bd loads this file automatically via gotenv.Load() before connecting.
    if [[ -n "$BHOST" && -n "${BPASS:-}" ]]; then
      mkdir -p "$TARGET_DIR/.beads"
      # Write via python — shell echo/printf can't be trusted with ! in passwords
      python3 -c "
import configparser, os
cp = configparser.ConfigParser()
cp.read(os.path.expanduser('~/.config/beads/credentials'))
key = '${BHOST}:${BPORT:-3307}'
pw = cp.get(key, 'password') if cp.has_section(key) and cp.has_option(key, 'password') else ''
if pw:
    with open('$TARGET_DIR/.beads/.env', 'w') as f:
        f.write(f'BEADS_DOLT_PASSWORD={pw}\n')
" 2>/dev/null
      chmod 600 "$TARGET_DIR/.beads/.env"
    fi

    if [[ "$DOLT_REACHABLE" == true ]]; then
      # Check if the database already exists on the server before init.
      # The default database name is the directory name (bd's --prefix default).
      BD_DB_NAME=$(basename "$TARGET_DIR")
      DB_EXISTS=false
      if [[ -n "$BHOST" && -n "${BPASS:-}" ]]; then
        # Query the server for existing databases matching our project name
        DB_EXISTS=$(python3 -c "
import subprocess, sys
try:
    result = subprocess.run(
        ['mysql', '-h', '${BHOST}', '-P', '${BPORT:-3307}', '-u', '${BUSER:-root}',
         '-p${BPASS}', '-N', '-e', 'SHOW DATABASES'],
        capture_output=True, text=True, timeout=5
    )
    # bd uses the directory name as db prefix, look for it
    for db in result.stdout.strip().split('\n'):
        if db.strip() == '${BD_DB_NAME}':
            print('true')
            sys.exit(0)
    print('false')
except:
    print('false')
" 2>/dev/null) || DB_EXISTS=false
      fi

      # Remote server needs --server flag with explicit connection args; embedded mode requires CGO
      BD_INIT_CMD="bd init"
      if [[ -n "$BHOST" ]]; then
        BD_INIT_CMD="bd init --server --server-host ${BHOST} --server-port ${BPORT:-3307} --server-user ${BUSER:-root}"
        # If DB already exists on server, tell bd to attach to it rather than create fresh
        if [[ "$DB_EXISTS" == "true" ]]; then
          BD_INIT_CMD="${BD_INIT_CMD} --database ${BD_DB_NAME}"
          echo -e "  Existing database '${BD_DB_NAME}' found on server — reconnecting"
        fi
      fi
      if (cd "$TARGET_DIR" && $BD_INIT_CMD 2>/dev/null); then
        echo -e "${GREEN}  ✓${NC} Initialized BEADS database (.beads/)"

        # Write port to the port file (gitignored, per-machine).
        # This is the primary port source for bd — NOT metadata.json.
        if [[ -n "${BPORT:-}" ]]; then
          echo -n "$BPORT" > "$TARGET_DIR/.beads/dolt-server.port"
          echo -e "${GREEN}  ✓${NC} Port file written: .beads/dolt-server.port ($BPORT)"
        fi

        # Write user to metadata.json (git-tracked, shared across team).
        if [[ -n "${BUSER:-}" ]]; then
          (cd "$TARGET_DIR" && bd dolt set user "$BUSER" 2>/dev/null) || true
        fi

        # Disable auto-backup and auto-push for remote server mode.
        # These try to use local filesystem paths the remote server can't access.
        if [[ -n "$BHOST" ]]; then
          (cd "$TARGET_DIR" && bd config set backup.enabled false 2>/dev/null) || true
          (cd "$TARGET_DIR" && bd config set autopush.enabled false 2>/dev/null) || true
          echo -e "${GREEN}  ✓${NC} Auto-backup and auto-push disabled (remote server mode)"
        fi
      else
        echo -e "${YELLOW}  ⊙${NC} BEADS database initialization failed (will retry at runtime)"
      fi
    fi
  fi
fi

# ─── Metaswarm Setup (if enabled) ─────────────────────────────────────
if [[ "$FEAT_METASWARM" == "yes" ]]; then
  echo ""
  echo -e "${BLUE}▸${NC} Metaswarm integration..."
  if ls ~/.claude/commands/brainstorm.md &>/dev/null 2>&1 || ls .claude/commands/brainstorm.md &>/dev/null 2>&1; then
    echo -e "${GREEN}  ✓${NC} Metaswarm commands detected"
  else
    echo -e "  Installing metaswarm..."
    if command -v claude &>/dev/null; then
      # Add marketplace source first, then install the plugin
      claude plugin marketplace add dsifry/metaswarm-marketplace 2>/dev/null
      if claude plugin install metaswarm 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} Metaswarm installed"
      else
        echo -e "${YELLOW}  ⊙${NC} Auto-install failed. Install manually:"
        echo -e "    ${GREEN}claude plugin marketplace add dsifry/metaswarm-marketplace${NC}"
        echo -e "    ${GREEN}claude plugin install metaswarm${NC}"
      fi
    else
      echo -e "${YELLOW}  ⊙${NC} Claude CLI not found. Install metaswarm manually:"
      echo -e "    ${GREEN}claude plugin marketplace add dsifry/metaswarm-marketplace${NC}"
      echo -e "    ${GREEN}claude plugin install metaswarm${NC}"
    fi
  fi
fi


# Install .claude/commands/ (Claude Code command scripts)
echo ""
echo -e "${BLUE}▸${NC} Installing Claude Code commands..."

# Copy actual command files to .claude/commands/ (where Claude Code looks)
for cmd_file in "$SOURCE_DIR"/claude/commands/*.md; do
  if [[ -f "$cmd_file" ]]; then
    filename="$(basename "$cmd_file")"
    # Skip README.md - it's a placeholder for .agent_process/claude/commands/
    if [[ "$filename" != "README.md" ]]; then
      cp "$cmd_file" "$TARGET_DIR/.claude/commands/$filename"
      echo -e "${GREEN}  ✓${NC} Installed command: $filename"
    fi
  fi
done

# Clean up old command files from .agent_process/claude/commands/ (from previous installs)
# These should only be in .claude/commands/ now
if [[ -d "$AGENT_PROCESS_DIR/claude/commands" ]]; then
  REMOVED_COUNT=0
  for old_cmd in "$AGENT_PROCESS_DIR"/claude/commands/ap_*.md; do
    if [[ -f "$old_cmd" ]]; then
      rm -f "$old_cmd"
      REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi
  done
  if [[ $REMOVED_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}  ⊙${NC} Removed $REMOVED_COUNT duplicate command files from .agent_process/claude/commands/"
  fi
fi

# Copy placeholder README to .agent_process/claude/commands/
if [[ -f "$SOURCE_DIR/claude/commands/README.md" ]]; then
  cp "$SOURCE_DIR/claude/commands/README.md" "$AGENT_PROCESS_DIR/claude/commands/"
  echo -e "${GREEN}  ✓${NC} Installed command reference in .agent_process/claude/commands/"
fi

# Copy documentation files to .agent_process/claude/
for doc_file in "$SOURCE_DIR"/claude/*.md; do
  if [[ -f "$doc_file" ]]; then
    cp "$doc_file" "$AGENT_PROCESS_DIR/claude/"
  fi
done

# Install orchestration files
echo ""
echo -e "${BLUE}▸${NC} Installing orchestration files..."

cp -r "$SOURCE_DIR"/orchestration/* "$AGENT_PROCESS_DIR/orchestration/"
echo -e "${GREEN}  ✓${NC} Installed $(find "$SOURCE_DIR/orchestration" -type f | wc -l | tr -d ' ') orchestration files"

# Install process files (with special handling for user-configurable files)
echo ""
echo -e "${BLUE}▸${NC} Installing process files..."

for process_file in "$SOURCE_DIR"/process/*; do
  filename="$(basename "$process_file")"
  target_file="$AGENT_PROCESS_DIR/process/$filename"

  # Skip central sync config - it's configured with user prompts below
  if [[ "$filename" == "ap_release_central_sync.md" ]]; then
    continue
  fi

  # Install local_environment_instructions.md only if it doesn't exist (preserve user config)
  if [[ "$filename" == "local_environment_instructions.md" ]]; then
    if [[ ! -f "$target_file" ]]; then
      cp "$process_file" "$target_file"
      echo -e "${GREEN}  ✓${NC} Installed local environment instructions template"
    else
      echo -e "${YELLOW}  ⊙${NC} Preserving existing local environment instructions"
    fi
    continue
  fi

  # Install all other process files normally
  cp "$process_file" "$target_file"
done
echo -e "${GREEN}  ✓${NC} Installed process files"

# Install scripts
echo ""
echo -e "${BLUE}▸${NC} Installing scripts..."

cp -r "$SOURCE_DIR"/scripts/* "$AGENT_PROCESS_DIR/scripts/"
echo -e "${GREEN}  ✓${NC} Installed $(find "$SOURCE_DIR/scripts" -type f | wc -l | tr -d ' ') script files"

# Install contract validators (used by evaluate-scope.sh)
if [[ -d "$SOURCE_DIR/test/contract" ]]; then
  for validator in "$SOURCE_DIR"/test/contract/validate-*.sh; do
    if [[ -f "$validator" ]]; then
      cp "$validator" "$AGENT_PROCESS_DIR/scripts/"
    fi
  done
  echo -e "${GREEN}  ✓${NC} Installed contract validators"
fi

# Make hook scripts executable
chmod +x "$AGENT_PROCESS_DIR/scripts"/*.sh 2>/dev/null || true
chmod +x "$AGENT_PROCESS_DIR/scripts/after_edit"/*.sh 2>/dev/null || true
echo -e "${GREEN}  ✓${NC} Made scripts executable"

# Install templates
echo ""
echo -e "${BLUE}▸${NC} Installing templates..."

cp -r "$SOURCE_DIR"/templates/* "$AGENT_PROCESS_DIR/templates/"
echo -e "${GREEN}  ✓${NC} Installed $(find "$SOURCE_DIR/templates" -type f | wc -l | tr -d ' ') template files"

# Install requirements_docs (template only - never overwrite user requirements)
echo ""
echo -e "${BLUE}▸${NC} Installing requirements documentation..."

# Check for existing user requirements files
EXISTING_REQS=$(find "$AGENT_PROCESS_DIR/requirements_docs" -type f -name "*.md" ! -name "_TEMPLATE_requirements.md" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$EXISTING_REQS" -gt 0 ]]; then
  echo -e "${YELLOW}  ⊙${NC} Preserving $EXISTING_REQS existing requirements file(s)"
fi

# Only copy the template file (never overwrite user's requirements)
cp "$SOURCE_DIR/requirements_docs/_TEMPLATE_requirements.md" "$AGENT_PROCESS_DIR/requirements_docs/"
echo -e "${GREEN}  ✓${NC} Installed/updated requirements template"

# Only copy work/ template files if work/ was just created
if [[ ! -f "$AGENT_PROCESS_DIR/work/current_iteration.conf.template" ]]; then
  echo ""
  echo -e "${BLUE}▸${NC} Installing work/ templates..."

  cp "$SOURCE_DIR/work/current_iteration.conf.template" "$AGENT_PROCESS_DIR/work/"
  echo -e "${GREEN}  ✓${NC} Installed iteration config template"

  # Copy master_requirements.md if it exists in source
  if [[ -f "$SOURCE_DIR/work/master_requirements.md" ]]; then
    cp "$SOURCE_DIR/work/master_requirements.md" "$AGENT_PROCESS_DIR/work/"
    echo -e "${GREEN}  ✓${NC} Installed master requirements template"
  fi
fi

# Documentation files are already installed above (commands.md, hooks.md, README.md)
echo ""
echo -e "${BLUE}▸${NC} Installing documentation..."
echo -e "${GREEN}  ✓${NC} Installed documentation files"

# Copy main README to .agent_process/
if [[ -f "$SOURCE_DIR/README.md" ]]; then
  cp "$SOURCE_DIR/README.md" "$AGENT_PROCESS_DIR/"
  echo -e "${GREEN}  ✓${NC} Installed README.md"
fi

# Central Repo Sync Configuration
echo ""
echo -e "${BLUE}▸${NC} Central repository sync configuration..."

# Check if config already exists
EXISTING_ENABLED=""
EXISTING_CENTRAL_REPO_PATH=""
EXISTING_PROJECT_FOLDER=""

if [[ -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" ]]; then
  # Extract existing values (only look in first 20 lines to avoid matching docs)
  EXISTING_ENABLED=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" 2>/dev/null | grep "^ENABLED:" | sed 's/ENABLED: *//' | tr -d ' ') || true
  EXISTING_CENTRAL_REPO_PATH=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" 2>/dev/null | grep "^CENTRAL_REPO_PATH:" | sed 's/CENTRAL_REPO_PATH: *//' | tr -d ' ') || true
  EXISTING_PROJECT_FOLDER=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" 2>/dev/null | grep "^PROJECT_FOLDER:" | sed 's/PROJECT_FOLDER: *//' | tr -d ' ') || true

  # Check if this is the old format (no ENABLED field but has real paths)
  if [[ -z "$EXISTING_ENABLED" && -n "$EXISTING_CENTRAL_REPO_PATH" && "$EXISTING_CENTRAL_REPO_PATH" != "<CENTRAL_REPO_PATH>" && "$EXISTING_CENTRAL_REPO_PATH" != "<not_configured>" ]]; then
    echo "" >&2
    echo -e "${RED}  ✗ ERROR: Old central sync config format detected${NC}" >&2
    echo "" >&2
    echo -e "${YELLOW}  Missing ENABLED: field in:${NC}" >&2
    echo -e "  $AGENT_PROCESS_DIR/process/ap_release_central_sync.md" >&2
    echo "" >&2
    echo -e "${YELLOW}  To fix, add this line after '## Configuration' section:${NC}" >&2
    echo -e "  ${GREEN}ENABLED: true${NC}" >&2
    echo "" >&2
    echo -e "  Current format:" >&2
    echo -e "  ${YELLOW}CENTRAL_REPO_PATH: $EXISTING_CENTRAL_REPO_PATH${NC}" >&2
    echo -e "  ${YELLOW}PROJECT_FOLDER: $EXISTING_PROJECT_FOLDER${NC}" >&2
    echo "" >&2
    echo -e "  Should be:" >&2
    echo -e "  ${GREEN}ENABLED: true${NC}" >&2
    echo -e "  ${GREEN}CENTRAL_REPO_PATH: $EXISTING_CENTRAL_REPO_PATH${NC}" >&2
    echo -e "  ${GREEN}PROJECT_FOLDER: $EXISTING_PROJECT_FOLDER${NC}" >&2
    echo "" >&2
    echo -e "  Then run install.sh again." >&2
    echo "" >&2
    exit 1
  elif [[ "$EXISTING_ENABLED" == "true" && -n "$EXISTING_CENTRAL_REPO_PATH" && "$EXISTING_CENTRAL_REPO_PATH" != "<CENTRAL_REPO_PATH>" && "$EXISTING_CENTRAL_REPO_PATH" != "<not_configured>" ]]; then
    # New format with enabled config - update template
    echo -e "${YELLOW}  ⊙${NC} Updating template, preserving enabled config"
    cp "$SOURCE_DIR/process/ap_release_central_sync.md" "$AGENT_PROCESS_DIR/process/"
    # Only replace the <PLACEHOLDER> tokens in the config block, not documentation examples
    sed -i.bak "s|<ENABLED>|true|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|<CENTRAL_REPO_PATH>|$EXISTING_CENTRAL_REPO_PATH|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|<PROJECT_FOLDER>|$EXISTING_PROJECT_FOLDER|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    rm -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md.bak"
    echo -e "${GREEN}  ✓${NC} Updated central sync config (enabled: $EXISTING_PROJECT_FOLDER)"
    EXISTING_ENABLED="true"  # Keep this set so we don't prompt below
  elif [[ "$EXISTING_ENABLED" == "false" ]]; then
    # Already has disabled config - update template but keep disabled
    echo -e "${YELLOW}  ⊙${NC} Updating template, keeping disabled state"
    cp "$SOURCE_DIR/process/ap_release_central_sync.md" "$AGENT_PROCESS_DIR/process/"
    sed -i.bak "s|<ENABLED>|false|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|<CENTRAL_REPO_PATH>|<not_configured>|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|<PROJECT_FOLDER>|<not_configured>|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    rm -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md.bak"
    echo -e "${GREEN}  ✓${NC} Updated central sync config (disabled)"
    EXISTING_ENABLED="false"  # Set so we don't prompt below
  else
    # Has file but no real values - treat as new install
    EXISTING_ENABLED=""
  fi
fi

# If no existing enabled config, prompt user
if [[ -z "$EXISTING_ENABLED" ]]; then
  echo ""
  echo -e "${YELLOW}  Optional: Configure central repository sync for agent process files.${NC}"
  echo -e "  This is useful if you track .agent_process files in a separate central repo."
  echo ""
  read -p "  Configure central repo sync? [y/N] " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""

    # Prompt for central repo path (required)
    while [[ -z "$CENTRAL_REPO_PATH" ]]; do
      read -p "  Central repo path (e.g., ~/PycharmProjects/agent-process-central): " CENTRAL_REPO_PATH
      if [[ -z "$CENTRAL_REPO_PATH" ]]; then
        echo -e "  ${RED}Error: Central repo path is required${NC}"
      fi
    done

    # Get project folder name - default to target directory name
    DEFAULT_PROJECT_FOLDER="$(basename "$TARGET_DIR")"
    read -p "  Project folder name in central repo [$DEFAULT_PROJECT_FOLDER]: " PROJECT_FOLDER
    PROJECT_FOLDER="${PROJECT_FOLDER:-$DEFAULT_PROJECT_FOLDER}"

    # Expand tilde in path (store as-is with tilde for portability)
    # Note: We keep the tilde in the config for portability across machines

    # Copy template and substitute placeholders only - ENABLED: true
    cp "$SOURCE_DIR/process/ap_release_central_sync.md" "$AGENT_PROCESS_DIR/process/"
    sed -i.bak "s|<ENABLED>|true|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|<CENTRAL_REPO_PATH>|$CENTRAL_REPO_PATH|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|<PROJECT_FOLDER>|$PROJECT_FOLDER|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    rm -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md.bak"

    echo -e "${GREEN}  ✓${NC} Created central sync config (enabled)"
  else
    # Copy template and substitute placeholders - ENABLED: false
    cp "$SOURCE_DIR/process/ap_release_central_sync.md" "$AGENT_PROCESS_DIR/process/"
    sed -i.bak "s|<ENABLED>|false|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|<CENTRAL_REPO_PATH>|<not_configured>|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    sed -i.bak "s|<PROJECT_FOLDER>|<not_configured>|" "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md"
    rm -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md.bak"

    echo -e "${GREEN}  ✓${NC} Created central sync config (disabled)"
  fi
fi

# Installation complete
# Ensure .gitignore excludes .run/ (ephemeral sub-agent scratch data)
GITIGNORE_FILE="$AGENT_PROCESS_DIR/.gitignore"
if [[ ! -f "$GITIGNORE_FILE" ]]; then
  cat > "$GITIGNORE_FILE" << 'GITIGNORE'
# Ephemeral sub-agent working data — recreated every run
**/.run/

# Session state — changes every ap_exec run
work/current_iteration.conf
work/current_work_unit.conf
GITIGNORE
  echo -e "${GREEN}  ✓${NC} Created .agent_process/.gitignore (.run/ excluded)"
else
  UPDATED=false
  if ! grep -q '\.run' "$GITIGNORE_FILE"; then
    echo "" >> "$GITIGNORE_FILE"
    echo "# Ephemeral sub-agent working data — recreated every run" >> "$GITIGNORE_FILE"
    echo "**/.run/" >> "$GITIGNORE_FILE"
    UPDATED=true
  fi
  if ! grep -q 'current_iteration\.conf' "$GITIGNORE_FILE"; then
    echo "" >> "$GITIGNORE_FILE"
    echo "# Session state — changes every ap_exec run" >> "$GITIGNORE_FILE"
    echo "work/current_iteration.conf" >> "$GITIGNORE_FILE"
    echo "work/current_work_unit.conf" >> "$GITIGNORE_FILE"
    UPDATED=true
  fi
  if [[ "$UPDATED" == true ]]; then
    echo -e "${GREEN}  ✓${NC} Updated .agent_process/.gitignore"
  fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Installation Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "  1. Review the installed files in:"
echo -e "     ${GREEN}$TARGET_DIR/.claude/commands/${NC}"
echo -e "     ${GREEN}$AGENT_PROCESS_DIR/${NC}"
if [[ "$AGENT_PROCESS_IS_SYMLINK" == true ]]; then
  echo -e "     ${YELLOW}(symlink to $SYMLINK_TARGET)${NC}"
fi
echo ""
echo "  2. Restart Claude Code to load new commands:"
echo -e "     ${BLUE}/clear${NC} or restart the session"
echo ""
echo "  3. Verify commands are available:"
echo -e "     ${BLUE}/ap_exec${NC}, ${BLUE}/ap_iteration_results${NC}, ${BLUE}/ap_release${NC}, ${BLUE}/ap_changelog_init${NC}"
echo ""
echo "  4. Create your first scope:"
echo -e "     • Create ${GREEN}requirements_docs/my_feature_requirements.md${NC}"
echo -e "     • Plan with ${BLUE}orchestration/plan-scope.md${NC}"
echo -e "     • Execute with ${BLUE}/ap_exec my_feature iteration_01${NC}"
echo ""
echo "  5. Set up scope-specific validation:"
echo -e "     • Copy ${GREEN}scripts/after_edit/validate-scope.sh.template${NC}"
echo -e "     • Create ${GREEN}scripts/after_edit/validate-my_feature.sh${NC}"
echo -e "     • Make executable: ${BLUE}chmod +x scripts/after_edit/validate-my_feature.sh${NC}"
echo ""
if [[ -f "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" ]]; then
  # Check if central sync is enabled (only look in first 20 lines to avoid matching docs)
  SYNC_ENABLED=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" | grep "^ENABLED:" | sed 's/ENABLED: *//' | tr -d ' ')

  if [[ "$SYNC_ENABLED" == "true" ]]; then
    echo -e "  ${GREEN}✓${NC} Central repo sync: ${GREEN}enabled${NC}"
    echo -e "     Config: ${GREEN}$AGENT_PROCESS_DIR/process/ap_release_central_sync.md${NC}"

    # Check if .agent_process is a symlink (central repo setup)
    if [[ "$AGENT_PROCESS_IS_SYMLINK" == true ]]; then
      # Read central repo path from config (only look in first 20 lines)
      CENTRAL_PATH=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" | grep "^CENTRAL_REPO_PATH:" | sed 's/CENTRAL_REPO_PATH: *//' | tr -d ' ')
      PROJECT_FOLDER=$(head -20 "$AGENT_PROCESS_DIR/process/ap_release_central_sync.md" | grep "^PROJECT_FOLDER:" | sed 's/PROJECT_FOLDER: *//' | tr -d ' ')

      if [[ -n "$CENTRAL_PATH" && "$CENTRAL_PATH" != "<CENTRAL_REPO_PATH>" && "$CENTRAL_PATH" != "<not_configured>" ]]; then
        echo ""
        echo -e "  ${YELLOW}⚠ ACTION REQUIRED:${NC} Central repo may have uncommitted changes"
        echo -e "     Run these commands to sync the central repo:"
        echo ""
        echo -e "     ${BLUE}cd $CENTRAL_PATH${NC}"
        echo -e "     ${BLUE}git add $PROJECT_FOLDER/${NC}"
        echo -e "     ${BLUE}git commit -m \"chore($PROJECT_FOLDER): update to ai_agent_process v$(cat "$SOURCE_DIR/VERSION")\"${NC}"
        echo -e "     ${BLUE}git push origin main${NC}"
        echo -e "     ${BLUE}cd -${NC}"
        echo ""
      fi
    fi
  else
    echo -e "  ${YELLOW}⊙${NC} Central repo sync: ${YELLOW}disabled${NC}"
    echo -e "     This project manages .agent_process/ locally"
  fi
  echo ""
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📖 Documentation: ${GREEN}$AGENT_PROCESS_DIR/claude/commands.md${NC}"
echo -e "🔧 Hooks guide: ${GREEN}$AGENT_PROCESS_DIR/claude/hooks.md${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Scroll up to review feature configuration and check for any warnings or errors."
echo ""
