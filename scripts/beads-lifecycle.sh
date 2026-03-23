#!/usr/bin/env bash
# beads-lifecycle.sh — BEADS state management for AP scopes
#
# Called by ap_exec and orchestrator prompts. Handles all BEADS
# operations as a single command — no multi-step inline bash needed.
# Exits 0 silently if BEADS is disabled or unavailable.
#
# Usage:
#   bash .agent_process/scripts/beads-lifecycle.sh start <scope>
#   bash .agent_process/scripts/beads-lifecycle.sh task-create <scope> <wu-id> <description>
#   bash .agent_process/scripts/beads-lifecycle.sh task-update <scope> <wu-id> <label>
#   bash .agent_process/scripts/beads-lifecycle.sh close <scope> <label>
#   bash .agent_process/scripts/beads-lifecycle.sh status <scope>

set -uo pipefail
# Note: not -e — we handle errors ourselves to avoid blocking the workflow

ACTION="${1:-}"
SCOPE="${2:-}"

if [[ -z "$ACTION" || -z "$SCOPE" ]]; then
  echo "[beads] Usage: beads-lifecycle.sh <start|task-create|task-update|close|status> <scope> [args...]" >&2
  exit 0  # Don't block workflow on usage error
fi

# --- Quick exit if BEADS is disabled or unavailable ---

CONFIG_FILE=".agent_process/quality-config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

BEADS_ENABLED=$(python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_FILE'))
    print('yes' if cfg.get('beads', {}).get('enabled', False) else 'no')
except:
    print('no')
" 2>/dev/null)

if [[ "$BEADS_ENABLED" != "yes" ]]; then
  exit 0
fi

if ! command -v bd &>/dev/null; then
  exit 0
fi

# --- Load server config and credentials ---

eval "$(python3 -c "
import json, os
try:
    cfg = json.load(open('$CONFIG_FILE'))
    server = cfg.get('beads', {}).get('server', {})
    host = server.get('host', '')
    in_docker = os.path.exists('/.dockerenv')
    if host and in_docker and host in ('127.0.0.1', 'localhost'):
        host = 'host.docker.internal'
    if host: print(f'export BEADS_DOLT_SERVER_HOST={host}')
    if server.get('port'): print(f'export BEADS_DOLT_SERVER_PORT={server[\"port\"]}')
    if server.get('user'): print(f'export BEADS_DOLT_SERVER_USER={server[\"user\"]}')
except:
    pass
" 2>/dev/null)" || true

# Load password from credentials file
CREDS_FILE="${HOME}/.claude/.beads-credentials"
if [[ -f "$CREDS_FILE" && -n "${BEADS_DOLT_SERVER_HOST:-}" ]]; then
  BPASS=$(python3 -c "
import configparser, os
cp = configparser.ConfigParser()
cp.read(os.path.expanduser('~/.claude/.beads-credentials'))
key = '${BEADS_DOLT_SERVER_HOST}:${BEADS_DOLT_SERVER_PORT:-3307}'
if cp.has_section(key) and cp.has_option(key, 'password'):
    print(cp.get(key, 'password'))
" 2>/dev/null) || true
  [[ -n "${BPASS:-}" ]] && export BEADS_DOLT_PASSWORD="$BPASS"
fi

# --- Execute the requested action ---

case "$ACTION" in
  start)
    # Create epic if it doesn't exist
    if ! bd epic show "$SCOPE" &>/dev/null; then
      bd epic create "$SCOPE" --description "AP scope: $SCOPE" 2>/dev/null && \
        echo "[beads] Created epic: $SCOPE" || true
    else
      echo "[beads] Epic already exists: $SCOPE"
    fi
    ;;

  task-create)
    WU_ID="${3:-}"
    DESC="${4:-}"
    if [[ -n "$WU_ID" ]]; then
      bd task create "$SCOPE" --id "$WU_ID" --description "$DESC" 2>/dev/null && \
        echo "[beads] Created task: $SCOPE/$WU_ID" || true
    fi
    ;;

  task-update)
    WU_ID="${3:-}"
    LABEL="${4:-}"
    if [[ -n "$WU_ID" && -n "$LABEL" ]]; then
      bd task update "$SCOPE" "$WU_ID" --label "$LABEL" 2>/dev/null && \
        echo "[beads] Updated $SCOPE/$WU_ID → $LABEL" || true
    fi
    ;;

  close)
    LABEL="${3:-approved}"
    bd epic close "$SCOPE" --label "$LABEL" 2>/dev/null && \
      echo "[beads] Closed epic: $SCOPE ($LABEL)" || true
    ;;

  status)
    bd epic show "$SCOPE" 2>/dev/null || echo "[beads] No epic found for: $SCOPE"
    ;;

  *)
    echo "[beads] Unknown action: $ACTION" >&2
    ;;
esac

exit 0
