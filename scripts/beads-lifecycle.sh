#!/usr/bin/env bash
# beads-lifecycle.sh — BEADS state management for AP scopes
#
# Called by ap_exec and orchestrator prompts. Handles all BEADS
# operations as a single command — no multi-step inline bash needed.
#
# Behavior depends on quality-config.json:
#   beads.enabled = true  → BEADS is required. Warn on failure, exit non-zero.
#   beads.enabled = false → Skip silently, exit 0.
#   No config file        → Skip silently, exit 0.
#
# Usage:
#   bash .agent_process/scripts/beads-lifecycle.sh start <scope>
#   bash .agent_process/scripts/beads-lifecycle.sh task-create <scope> <wu-id> <description>
#   bash .agent_process/scripts/beads-lifecycle.sh task-update <scope> <wu-id> <label>
#   bash .agent_process/scripts/beads-lifecycle.sh close <scope> <label>
#   bash .agent_process/scripts/beads-lifecycle.sh status <scope>
#   bash .agent_process/scripts/beads-lifecycle.sh verify <scope> <iteration>

set -uo pipefail

ACTION="${1:-}"
SCOPE="${2:-}"

if [[ -z "$ACTION" || -z "$SCOPE" ]]; then
  echo "[beads] Usage: beads-lifecycle.sh <start|task-create|task-update|close|status|verify> <scope> [args...]" >&2
  exit 1
fi

# --- Check if BEADS is enabled ---

CONFIG_FILE=".agent_process/quality-config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0  # No config = not an AP project, skip silently
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
  exit 0  # Disabled = skip silently
fi

# --- From here on, BEADS is ENABLED. Failures should be visible. ---

BEADS_AUTO_INSTALL=$(python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_FILE'))
    print('yes' if cfg.get('beads', {}).get('auto_install', True) else 'no')
except:
    print('yes')
" 2>/dev/null)

# --- Ensure bd is available ---

if ! command -v bd &>/dev/null; then
  if [[ "$BEADS_AUTO_INSTALL" == "yes" ]]; then
    echo "[beads] bd not found — attempting install..." >&2
    INSTALLED=false
    if command -v npm &>/dev/null && npm install -g @beads/bd 2>/dev/null; then
      INSTALLED=true
      echo "[beads] Installed bd via npm" >&2
    elif command -v brew &>/dev/null && brew install beads 2>/dev/null; then
      INSTALLED=true
      echo "[beads] Installed bd via Homebrew" >&2
    elif command -v curl &>/dev/null && curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash 2>/dev/null; then
      INSTALLED=true
      echo "[beads] Installed bd via installer script" >&2
    fi
    if [[ "$INSTALLED" == false ]]; then
      echo "[beads] ERROR: BEADS is enabled but bd could not be installed." >&2
      echo "[beads] Install manually: npm install -g @beads/bd" >&2
      echo "[beads] Or disable BEADS in .agent_process/quality-config.json" >&2
      exit 1
    fi
  else
    echo "[beads] ERROR: BEADS is enabled but bd is not installed (auto_install: false)." >&2
    echo "[beads] Install manually: npm install -g @beads/bd" >&2
    exit 1
  fi
fi

# --- Load server config and credentials ---

IN_DOCKER=false
[[ -f "/.dockerenv" ]] && IN_DOCKER=true

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
# In Docker, also check for host.docker.internal key in addition to the original host
CREDS_FILE="${HOME}/.claude/.beads-credentials"
if [[ -f "$CREDS_FILE" && -n "${BEADS_DOLT_SERVER_HOST:-}" ]]; then
  BPASS=$(python3 -c "
import configparser, os
cp = configparser.ConfigParser()
cp.read(os.path.expanduser('~/.claude/.beads-credentials'))
host = '${BEADS_DOLT_SERVER_HOST}'
port = '${BEADS_DOLT_SERVER_PORT:-3307}'
# Try the exact key first, then fallback keys for Docker host rewriting
for key in [f'{host}:{port}', f'127.0.0.1:{port}', f'host.docker.internal:{port}', f'localhost:{port}']:
    if cp.has_section(key) and cp.has_option(key, 'password'):
        print(cp.get(key, 'password'))
        break
" 2>/dev/null) || true
  [[ -n "${BPASS:-}" ]] && export BEADS_DOLT_PASSWORD="$BPASS"
fi

# --- Ensure bd init has been run ---

if [[ ! -f ".beads/metadata.json" ]]; then
  echo "[beads] No .beads/metadata.json — running bd init..." >&2
  if bd init 2>/dev/null; then
    echo "[beads] bd init completed" >&2
  else
    echo "[beads] WARNING: bd init failed — BEADS tracking may not work" >&2
    # Don't exit — breadcrumb tracking still works even if bd init fails
  fi
fi

# --- Breadcrumb tracking ---
# Writes a line to .beads-state so the orchestrator can verify which
# lifecycle steps actually ran. This file survives even if bd fails.

ITERATION="${BEADS_ITERATION:-}"

breadcrumb() {
  local action="$1"
  local detail="${2:-}"
  local state_dir=".agent_process/work/${SCOPE}"

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

    # Check if an epic for this scope already exists
    EPIC_ID=$(bd query "type=epic AND title=${SCOPE}" --json 2>/dev/null \
      | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

    if [[ -n "$EPIC_ID" ]]; then
      echo "[beads] Epic already exists: $SCOPE ($EPIC_ID)"
      breadcrumb "EPIC_FOUND" "${EPIC_ID}"
    else
      EPIC_ID=$(bd create "$SCOPE" --type epic \
        --description "AP scope: $SCOPE" \
        --silent 2>/dev/null) || true

      if [[ -n "$EPIC_ID" ]]; then
        echo "[beads] Created epic: $SCOPE ($EPIC_ID)"
        breadcrumb "EPIC_CREATED" "success:${EPIC_ID}"
      else
        echo "[beads] WARNING: Failed to create epic for $SCOPE" >&2
        breadcrumb "ERROR" "epic_create_failed"
        # Don't exit — breadcrumbs still track state
      fi
    fi
    ;;

  task-create)
    WU_ID="${3:-}"
    DESC="${4:-}"
    if [[ -n "$WU_ID" ]]; then
      breadcrumb "TASK_CREATE" "$WU_ID"

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

    EPIC_ID=$(bd query "type=epic AND title=${SCOPE}" --json 2>/dev/null \
      | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

    if [[ -n "$EPIC_ID" ]]; then
      bd close "$EPIC_ID" --reason "AP decision: $LABEL" 2>/dev/null && \
        echo "[beads] Closed epic: $SCOPE ($EPIC_ID) — $LABEL" || \
        echo "[beads] WARNING: Failed to close epic $EPIC_ID" >&2
    else
      echo "[beads] WARNING: No epic found for: $SCOPE" >&2
    fi
    ;;

  status)
    EPIC_ID=$(bd query "type=epic AND title=${SCOPE}" --json 2>/dev/null \
      | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

    if [[ -n "$EPIC_ID" ]]; then
      bd epic status "$EPIC_ID" 2>/dev/null
    else
      echo "[beads] No epic found for: $SCOPE"
    fi
    ;;

  verify)
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

    HAS_START=$(grep -c "^EPIC_START=" "$STATE_FILE" 2>/dev/null || echo "0")
    HAS_CREATE=$(grep -c "^EPIC_CREATED=\|^EPIC_FOUND=" "$STATE_FILE" 2>/dev/null || echo "0")
    HAS_ERROR=$(grep -c "^ERROR=" "$STATE_FILE" 2>/dev/null || echo "0")

    if [[ "$HAS_START" -gt 0 && "$HAS_CREATE" -gt 0 ]]; then
      echo "✅ Epic lifecycle: started and created"
    elif [[ "$HAS_START" -gt 0 ]]; then
      echo "⚠️  Epic lifecycle: started but creation may have failed"
    else
      echo "❌ Epic lifecycle: no start event found"
    fi

    if [[ "$HAS_ERROR" -gt 0 ]]; then
      echo "⚠️  Errors recorded: $HAS_ERROR (BEADS had issues but workflow continued)"
    fi

    TASK_COUNT=$(grep -c "^TASK_CREATE=" "$STATE_FILE" 2>/dev/null || echo "0")
    TASK_COMPLETES=$(grep "^TASK_UPDATE=.*complete" "$STATE_FILE" 2>/dev/null | wc -l || echo "0")

    if [[ "$TASK_COUNT" -gt 0 ]]; then
      echo "📋 Work units: ${TASK_COUNT} created, ${TASK_COMPLETES} completed"
    else
      echo "📋 Work units: none (single-pass execution)"
    fi

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
    exit 1
    ;;
esac

exit 0
