#!/usr/bin/env bash
# tracker-utils.sh — Read/write helpers for scope-tracker.jsonl and scope-events.log
#
# Source this from lifecycle scripts:
#   source "$(dirname "$0")/lib/tracker-utils.sh"
#
# Provides:
#   tracker_read_scope  <scope>          → prints the JSON line for <scope>
#   tracker_write_scope <scope> <json>   → atomic upsert of <scope> in tracker
#   tracker_get_field   <scope> <field>  → prints a single field value
#   events_log          <scope> <type> [key=val ...]  → appends to scope-events.log
#
# Designed for bash 3.2+ (macOS) and bash 5+.
# jq is preferred but we degrade gracefully to grep+sed when it's missing.

# --- Configuration ---

# Where the tracker lives — override TRACKER_FILE to test against a temp path
TRACKER_FILE="${TRACKER_FILE:-.agent_process/work/scope-tracker.jsonl}"

# Where scope event logs live — override EVENTS_DIR for testing
EVENTS_DIR="${EVENTS_DIR:-.agent_process/work}"

# --- Internal helpers ---

_has_jq() {
  command -v jq &>/dev/null
}

# ISO-8601 timestamp, UTC. Works on both GNU date and BSD date (macOS).
_timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "1970-01-01T00:00:00Z"; }

# --- Public API ---

# tracker_read_scope <scope>
#   Prints the JSON line for the given scope, or nothing if not found.
tracker_read_scope() {
  local scope="$1"
  if [[ -z "$scope" ]]; then
    echo "tracker_read_scope: scope argument required" >&2
    return 1
  fi
  if [[ ! -f "$TRACKER_FILE" ]]; then
    return 0  # no file, no scope — not an error
  fi

  if _has_jq; then
    jq -c --arg s "$scope" 'select(.scope==$s)' "$TRACKER_FILE" 2>/dev/null
  else
    # Fallback: grep for the scope name, anchored to prevent prefix collisions
    grep "\"scope\":\"${scope}\"[,}]" "$TRACKER_FILE" 2>/dev/null | head -1
  fi
}

# tracker_write_scope <scope> <json>
#   Atomic upsert: replaces the line for <scope> or appends if new.
#   Uses temp-file + mv to prevent corruption.
tracker_write_scope() {
  local scope="$1"
  local json="$2"
  if [[ -z "$scope" || -z "$json" ]]; then
    echo "tracker_write_scope: scope and json arguments required" >&2
    return 1
  fi

  local dir
  dir="$(dirname "$TRACKER_FILE")"
  mkdir -p "$dir"

  local tmp_file="${TRACKER_FILE}.tmp"
  local found=false

  # If the tracker file exists, copy all lines except the one we're replacing
  if [[ -f "$TRACKER_FILE" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      # Check if this line is for our scope
      local line_scope=""
      if _has_jq; then
        line_scope=$(echo "$line" | jq -r '.scope' 2>/dev/null)
      else
        # sed to extract scope value — handles the common JSON shape
        line_scope=$(echo "$line" | sed -n 's/.*"scope":"\([^"]*\)".*/\1/p')
      fi

      if [[ "$line_scope" == "$scope" ]]; then
        echo "$json" >> "$tmp_file"
        found=true
      else
        echo "$line" >> "$tmp_file"
      fi
    done < "$TRACKER_FILE"
  fi

  # New scope — append
  if [[ "$found" == false ]]; then
    echo "$json" >> "$tmp_file"
  fi

  # Atomic rename — the whole point of this dance
  mv "$tmp_file" "$TRACKER_FILE"
}

# tracker_get_field <scope> <field>
#   Convenience: prints a single top-level field value from the scope's JSON.
tracker_get_field() {
  local scope="$1"
  local field="$2"
  if [[ -z "$scope" || -z "$field" ]]; then
    echo "tracker_get_field: scope and field arguments required" >&2
    return 1
  fi

  local line
  line=$(tracker_read_scope "$scope")
  [[ -z "$line" ]] && return 0

  if _has_jq; then
    echo "$line" | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null
  else
    # Best-effort extraction for simple string fields.
    # Nested objects? You really want jq for that.
    echo "$line" | sed -n "s/.*\"${field}\":\"\([^\"]*\)\".*/\1/p"
  fi
}

# events_log <scope> <event_type> [key=value ...]
#   Appends one event line to the scope's scope-events.log.
#
#   Example:
#     events_log auth_middleware_01 SCOPE_START iteration=iteration_01
#
#   Produces:
#     2026-04-01T10:00:00Z SCOPE_START scope=auth_middleware_01 iteration=iteration_01
events_log() {
  local scope="$1"
  local event_type="$2"
  shift 2

  if [[ -z "$scope" || -z "$event_type" ]]; then
    echo "events_log: scope and event_type arguments required" >&2
    return 1
  fi

  # Validate event type — reject typos early
  local valid_types="SCOPE_START SCOPE_ADOPT SCOPE_ASSOCIATE SCOPE_SPLIT ITERATION_START ITERATION_CLOSE WU_CREATE WU_UPDATE SCOPE_CLOSE COMMENT ERROR"
  local type_ok=false
  for vt in $valid_types; do
    if [[ "$event_type" == "$vt" ]]; then
      type_ok=true
      break
    fi
  done
  if [[ "$type_ok" == false ]]; then
    echo "events_log: invalid event type '${event_type}'" >&2
    echo "  valid types: ${valid_types}" >&2
    return 1
  fi

  local scope_dir="${EVENTS_DIR}/${scope}"
  mkdir -p "$scope_dir"

  local log_file="${scope_dir}/scope-events.log"
  local ts
  ts=$(_timestamp)

  # Build the event line: timestamp + type + scope=X + any extra k=v pairs
  local event_line="${ts} ${event_type} scope=${scope}"
  for kv in "$@"; do
    event_line="${event_line} ${kv}"
  done

  echo "$event_line" >> "$log_file"
}
