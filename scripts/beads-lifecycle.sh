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
#   bash .agent_process/scripts/beads-lifecycle.sh verify <scope> <iteration>
#
# Every action writes a breadcrumb to .beads-state so the orchestrator
# can independently verify which steps ran, even if BEADS itself failed.

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

# --- Breadcrumb tracking ---
# Writes a line to .beads-state so the orchestrator can verify which
# lifecycle steps actually ran. This file survives even if bd fails.

ITERATION="${BEADS_ITERATION:-}"  # Set by caller if known

breadcrumb() {
  local action="$1"
  local detail="${2:-}"
  local state_dir=".agent_process/work/${SCOPE}"

  # Find the iteration dir — use explicit ITERATION if set, otherwise latest
  if [[ -n "$ITERATION" ]]; then
    state_dir="${state_dir}/${ITERATION}"
  fi

  mkdir -p "$state_dir" 2>/dev/null || true
  echo "${action}=$(date -Iseconds) ${detail}" >> "${state_dir}/.beads-state" 2>/dev/null || true
}

# --- Execute the requested action ---

case "$ACTION" in
  start)
    breadcrumb "EPIC_START" "$SCOPE"
    if ! bd epic show "$SCOPE" &>/dev/null; then
      if bd epic create "$SCOPE" --description "AP scope: $SCOPE" 2>/dev/null; then
        echo "[beads] Created epic: $SCOPE"
        breadcrumb "EPIC_CREATED" "success"
      else
        breadcrumb "EPIC_CREATED" "bd_failed"
      fi
    else
      echo "[beads] Epic already exists: $SCOPE"
      breadcrumb "EPIC_CREATED" "already_exists"
    fi
    ;;

  task-create)
    WU_ID="${3:-}"
    DESC="${4:-}"
    if [[ -n "$WU_ID" ]]; then
      breadcrumb "TASK_CREATE" "$WU_ID"
      bd task create "$SCOPE" --id "$WU_ID" --description "$DESC" 2>/dev/null && \
        echo "[beads] Created task: $SCOPE/$WU_ID" || true
    fi
    ;;

  task-update)
    WU_ID="${3:-}"
    LABEL="${4:-}"
    if [[ -n "$WU_ID" && -n "$LABEL" ]]; then
      breadcrumb "TASK_UPDATE" "$WU_ID $LABEL"
      bd task update "$SCOPE" "$WU_ID" --label "$LABEL" 2>/dev/null && \
        echo "[beads] Updated $SCOPE/$WU_ID → $LABEL" || true
    fi
    ;;

  close)
    LABEL="${3:-approved}"
    breadcrumb "EPIC_CLOSE" "$LABEL"
    bd epic close "$SCOPE" --label "$LABEL" 2>/dev/null && \
      echo "[beads] Closed epic: $SCOPE ($LABEL)" || true
    ;;

  status)
    bd epic show "$SCOPE" 2>/dev/null || echo "[beads] No epic found for: $SCOPE"
    ;;

  verify)
    # Orchestrator calls this to independently check what happened.
    # Reads breadcrumbs, not bd state — works even if BEADS is down.
    ITERATION="${3:-}"
    STATE_FILE=".agent_process/work/${SCOPE}/${ITERATION}/.beads-state"

    echo "## BEADS Verification: ${SCOPE}/${ITERATION}"
    echo ""

    if [[ ! -f "$STATE_FILE" ]]; then
      echo "⚠️  No .beads-state file found — Step 0.5 was likely skipped"
      echo "   File-based state (current_iteration.conf) was used instead"
      exit 0
    fi

    echo "Breadcrumbs found:"
    cat "$STATE_FILE"
    echo ""

    # Check for expected lifecycle events
    HAS_START=$(grep -c "^EPIC_START=" "$STATE_FILE" 2>/dev/null || echo "0")
    HAS_CREATE=$(grep -c "^EPIC_CREATED=" "$STATE_FILE" 2>/dev/null || echo "0")

    if [[ "$HAS_START" -gt 0 && "$HAS_CREATE" -gt 0 ]]; then
      echo "✅ Epic lifecycle: started and created"
    elif [[ "$HAS_START" -gt 0 ]]; then
      echo "⚠️  Epic lifecycle: started but creation may have failed"
    else
      echo "❌ Epic lifecycle: no start event found"
    fi

    # Check task tracking if work units were used
    TASK_COUNT=$(grep -c "^TASK_CREATE=" "$STATE_FILE" 2>/dev/null || echo "0")
    TASK_COMPLETES=$(grep "^TASK_UPDATE=.*complete" "$STATE_FILE" 2>/dev/null | wc -l || echo "0")

    if [[ "$TASK_COUNT" -gt 0 ]]; then
      echo "📋 Work units: ${TASK_COUNT} created, ${TASK_COMPLETES} completed"
    else
      echo "📋 Work units: none (single-pass execution)"
    fi

    # Check if epic was closed
    HAS_CLOSE=$(grep -c "^EPIC_CLOSE=" "$STATE_FILE" 2>/dev/null || echo "0")
    if [[ "$HAS_CLOSE" -gt 0 ]]; then
      CLOSE_LABEL=$(grep "^EPIC_CLOSE=" "$STATE_FILE" | tail -1 | sed 's/^EPIC_CLOSE=[^ ]* //')
      echo "🏁 Epic closed: $CLOSE_LABEL"
    else
      echo "🔄 Epic still open (awaiting orchestrator decision)"
    fi
    ;;

  *)
    echo "[beads] Unknown action: $ACTION" >&2
    ;;
esac

exit 0
