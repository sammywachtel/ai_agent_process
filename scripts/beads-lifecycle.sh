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
#   bash .agent_process/scripts/beads-lifecycle.sh set-iteration <scope> <iteration>
#   bash .agent_process/scripts/beads-lifecycle.sh get-iteration <scope>
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

# --- Ensure bd init has been run ---
# If .beads/metadata.json exists, bd already has native config (host/port/user
# set via bd dolt set) and the bd wrapper at ~/.local/bin/bd handles credential
# loading. No config parsing needed here.
#
# If metadata.json is MISSING, we need to run bd init. This requires loading
# server config from quality-config.json and credentials from ~/.config/beads/credentials
# since bd's native config doesn't exist yet.

if [[ ! -f ".beads/metadata.json" ]]; then
  echo "[beads] No .beads/metadata.json — running bd init..." >&2

  # Load server config from quality-config.json (only needed for init)
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

  # Load password from credentials file (pure bash INI parsing)
  CREDS_FILE="${BEADS_CREDENTIALS_FILE:-${HOME}/.config/beads/credentials}"
  if [[ -f "$CREDS_FILE" && -n "${BEADS_DOLT_SERVER_HOST:-}" ]]; then
    SERVER_KEY="${BEADS_DOLT_SERVER_HOST}:${BEADS_DOLT_SERVER_PORT:-3307}"
    BPASS=""
    in_section=false
    while IFS= read -r line; do
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -z "$line" ]] && continue
      if [[ "$line" =~ ^\[(.+)\]$ ]]; then
        [[ "${BASH_REMATCH[1]}" == "$SERVER_KEY" ]] && in_section=true || { $in_section && break; in_section=false; }
        continue
      fi
      if $in_section && [[ "$line" =~ ^password[[:space:]]*=[[:space:]]*(.*) ]]; then
        BPASS="${BASH_REMATCH[1]}"
        break
      fi
    done < "$CREDS_FILE"
    [[ -n "$BPASS" ]] && export BEADS_DOLT_PASSWORD="$BPASS"
  fi

  # Create .beads/.env with password for init-time auth.
  # bd loads this via gotenv.Load() before connecting.
  if [[ -n "${BEADS_DOLT_PASSWORD:-}" ]]; then
    mkdir -p .beads
    echo "BEADS_DOLT_PASSWORD=${BEADS_DOLT_PASSWORD}" > .beads/.env
    chmod 600 .beads/.env
  fi

  if bd init 2>/dev/null; then
    echo "[beads] bd init completed" >&2
    # Write server config to bd's native storage so future bd calls
    # work without env vars. Mirrors what install.sh does.
    # Write port to the port file (gitignored, per-machine) — this is the
    # primary port source for bd, not metadata.json.
    if [[ -n "${BEADS_DOLT_SERVER_PORT:-}" ]]; then
      echo -n "$BEADS_DOLT_SERVER_PORT" > .beads/dolt-server.port
    fi
    # User goes to metadata.json (git-tracked, shared across team).
    [[ -n "${BEADS_DOLT_SERVER_USER:-}" ]] && bd dolt set user "$BEADS_DOLT_SERVER_USER" 2>/dev/null || true
    # Disable auto-backup and auto-push for remote server mode.
    if [[ -n "${BEADS_DOLT_SERVER_HOST:-}" ]]; then
      bd config set backup.enabled false 2>/dev/null || true
      bd config set autopush.enabled false 2>/dev/null || true
    fi
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

    # Set iteration state in BEADS (single source of truth when enabled)
    if [[ -n "$EPIC_ID" && -n "$ITERATION" ]]; then
      bd set-state "$EPIC_ID" "iteration=$ITERATION" --reason "ap_exec start" 2>/dev/null && \
        echo "[beads] Iteration state: $ITERATION" || true
      # Also write fallback file for BEADS-disabled compatibility
      cat > .agent_process/work/current_iteration.conf <<EOF
SCOPE=$SCOPE
ITERATION=$ITERATION
EOF
    fi
    ;;

  set-iteration)
    # Update the iteration pointer in BEADS and the fallback conf file
    NEW_ITERATION="${3:-}"
    if [[ -z "$NEW_ITERATION" ]]; then
      echo "[beads] Usage: set-iteration <scope> <iteration>" >&2
      exit 1
    fi

    EPIC_ID=$(bd query "type=epic AND title=${SCOPE}" --json 2>/dev/null \
      | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

    if [[ -n "$EPIC_ID" ]]; then
      bd set-state "$EPIC_ID" "iteration=$NEW_ITERATION" --reason "iteration update" 2>/dev/null && \
        echo "[beads] Iteration state: $NEW_ITERATION" || \
        echo "[beads] WARNING: Failed to set iteration state in BEADS" >&2
    fi

    # Always write fallback file
    cat > .agent_process/work/current_iteration.conf <<EOF
SCOPE=$SCOPE
ITERATION=$NEW_ITERATION
EOF
    ;;

  get-iteration)
    # Read current iteration — BEADS first, conf file fallback
    EPIC_ID=$(bd query "type=epic AND title=${SCOPE}" --json 2>/dev/null \
      | python3 -c "import json,sys; issues=json.load(sys.stdin); print(issues[0]['id'] if issues else '')" 2>/dev/null) || true

    if [[ -n "$EPIC_ID" ]]; then
      BEADS_ITER=$(bd state "$EPIC_ID" iteration 2>/dev/null | grep -o 'iteration[^ ]*' || true)
      if [[ -n "$BEADS_ITER" ]]; then
        echo "$BEADS_ITER"
        exit 0
      fi
    fi

    # Fallback to conf file
    if [[ -f ".agent_process/work/current_iteration.conf" ]]; then
      grep "^ITERATION=" .agent_process/work/current_iteration.conf | cut -d= -f2
    else
      echo ""
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
      # Record final iteration state before closing
      if [[ -n "$ITERATION" ]]; then
        bd set-state "$EPIC_ID" "iteration=$ITERATION" --reason "final iteration at $LABEL" 2>/dev/null || true
      fi
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
