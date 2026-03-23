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
#
# Real bd API:
#   bd create "title" --type epic        Create an epic issue
#   bd create "title" --parent <id>      Create a child task under an epic
#   bd query "type:epic title:<scope>"   Find existing epic by title
#   bd update <id> --labels <label>      Update labels on an issue
#   bd close <id> --reason <reason>      Close an issue
#   bd show <id>                         Show issue details
#   bd list                              List all issues
#   bd epic status <id>                  Show epic completion

case "$ACTION" in
  start)
    breadcrumb "EPIC_START" "$SCOPE"

    # Check if an epic for this scope already exists
    EPIC_ID=$(bd query "type=epic AND title=${SCOPE}" --json 2>/dev/null \
      | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

    if [[ -n "$EPIC_ID" ]]; then
      echo "[beads] Epic already exists: $SCOPE ($EPIC_ID)"
      breadcrumb "EPIC_CREATED" "already_exists:${EPIC_ID}"
    else
      # Create a new epic for this scope
      EPIC_ID=$(bd create "$SCOPE" --type epic \
        --description "AP scope: $SCOPE" \
        --silent 2>/dev/null) || true

      if [[ -n "$EPIC_ID" ]]; then
        echo "[beads] Created epic: $SCOPE ($EPIC_ID)"
        breadcrumb "EPIC_CREATED" "success:${EPIC_ID}"
      else
        echo "[beads] Failed to create epic (bd error — continuing without BEADS)" >&2
        breadcrumb "EPIC_CREATED" "bd_failed"
      fi
    fi
    ;;

  task-create)
    WU_ID="${3:-}"
    DESC="${4:-}"
    if [[ -n "$WU_ID" ]]; then
      breadcrumb "TASK_CREATE" "$WU_ID"

      # Find the parent epic ID
      EPIC_ID=$(bd query "type=epic AND title=${SCOPE}" --json 2>/dev/null \
        | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

      if [[ -n "$EPIC_ID" ]]; then
        TASK_ID=$(bd create "${WU_ID}: ${DESC}" --parent "$EPIC_ID" --silent 2>/dev/null) || true
        if [[ -n "$TASK_ID" ]]; then
          echo "[beads] Created task: $WU_ID ($TASK_ID) under $EPIC_ID"
        fi
      fi
    fi
    ;;

  task-update)
    WU_ID="${3:-}"
    LABEL="${4:-}"
    if [[ -n "$WU_ID" && -n "$LABEL" ]]; then
      breadcrumb "TASK_UPDATE" "$WU_ID $LABEL"

      # Find the task by title prefix (WU-ID is in the title)
      TASK_ID=$(bd query "title=${WU_ID}" --json 2>/dev/null \
        | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

      if [[ -n "$TASK_ID" ]]; then
        bd label "$TASK_ID" --add "$LABEL" 2>/dev/null && \
          echo "[beads] Updated $WU_ID ($TASK_ID) → $LABEL" || true
      fi
    fi
    ;;

  close)
    LABEL="${3:-approved}"
    breadcrumb "EPIC_CLOSE" "$LABEL"

    # Find the epic by title
    EPIC_ID=$(bd query "type=epic AND title=${SCOPE}" --json 2>/dev/null \
      | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

    if [[ -n "$EPIC_ID" ]]; then
      bd close "$EPIC_ID" --reason "AP decision: $LABEL" 2>/dev/null && \
        echo "[beads] Closed epic: $SCOPE ($EPIC_ID) — $LABEL" || true
    else
      echo "[beads] No epic found for: $SCOPE"
    fi
    ;;

  status)
    # Find the epic and show its status
    EPIC_ID=$(bd query "type=epic AND title=${SCOPE}" --json 2>/dev/null \
      | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

    if [[ -n "$EPIC_ID" ]]; then
      bd epic status "$EPIC_ID" 2>/dev/null
    else
      echo "[beads] No epic found for: $SCOPE"
    fi
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
