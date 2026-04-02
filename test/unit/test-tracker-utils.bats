#!/usr/bin/env bats
# test-tracker-utils.bats — Unit tests for scope-tracker.jsonl and scope-events.log
#
# Tests the four public functions in scripts/lib/tracker-utils.sh:
#   tracker_read_scope, tracker_write_scope, tracker_get_field, events_log
#
# Also validates the contract validator catches what it should catch.

LIB="scripts/lib/tracker-utils.sh"
VALIDATOR="test/contract/validate-scope-events.sh"

setup() {
  export TEST_DIR="$(mktemp -d)"
  export ORIG_DIR="$(pwd)"

  # Point tracker at our temp playground
  export TRACKER_FILE="${TEST_DIR}/scope-tracker.jsonl"
  export EVENTS_DIR="${TEST_DIR}/events"
  mkdir -p "$EVENTS_DIR"

  # Source the library under test
  source "$ORIG_DIR/$LIB"
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR"
}

# ─────────────────────────────────────────────
# tracker_write_scope + tracker_read_scope
# ─────────────────────────────────────────────

@test "create scope and read it back" {
  local json='{"scope":"widget_01","status":"planning","current_iteration":"iteration_01","iterations":{},"ts":"2026-04-01T10:00:00Z"}'
  tracker_write_scope "widget_01" "$json"

  run tracker_read_scope "widget_01"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"scope":"widget_01"'
  echo "$output" | grep -q '"status":"planning"'
}

@test "update scope status and read back" {
  # Create
  local json_v1='{"scope":"auth_01","status":"planning","current_iteration":"iteration_01","iterations":{},"ts":"2026-04-01T10:00:00Z"}'
  tracker_write_scope "auth_01" "$json_v1"

  # Update
  local json_v2='{"scope":"auth_01","status":"executing","current_iteration":"iteration_01","iterations":{},"ts":"2026-04-01T11:00:00Z"}'
  tracker_write_scope "auth_01" "$json_v2"

  run tracker_read_scope "auth_01"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"status":"executing"'

  # Should be exactly one line for this scope
  local count
  count=$(grep -c '"scope":"auth_01"' "$TRACKER_FILE")
  [ "$count" -eq 1 ]
}

@test "two scopes in same file both readable" {
  local json_a='{"scope":"scope_alpha","status":"planning","current_iteration":"iteration_01","iterations":{},"ts":"2026-04-01T10:00:00Z"}'
  local json_b='{"scope":"scope_beta","status":"executing","current_iteration":"iteration_02","iterations":{},"ts":"2026-04-01T11:00:00Z"}'

  tracker_write_scope "scope_alpha" "$json_a"
  tracker_write_scope "scope_beta" "$json_b"

  # Both exist
  run tracker_read_scope "scope_alpha"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"scope":"scope_alpha"'

  run tracker_read_scope "scope_beta"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"scope":"scope_beta"'

  # File has exactly 2 lines
  local line_count
  line_count=$(wc -l < "$TRACKER_FILE" | tr -d ' ')
  [ "$line_count" -eq 2 ]
}

@test "update one scope doesn't clobber the other" {
  local json_a='{"scope":"scope_a","status":"planning","current_iteration":"iteration_01","iterations":{},"ts":"2026-04-01T10:00:00Z"}'
  local json_b='{"scope":"scope_b","status":"planning","current_iteration":"iteration_01","iterations":{},"ts":"2026-04-01T10:00:00Z"}'
  tracker_write_scope "scope_a" "$json_a"
  tracker_write_scope "scope_b" "$json_b"

  # Update scope_a only
  local json_a2='{"scope":"scope_a","status":"complete","current_iteration":"iteration_03","iterations":{},"ts":"2026-04-01T15:00:00Z"}'
  tracker_write_scope "scope_a" "$json_a2"

  # scope_b should still be planning
  run tracker_get_field "scope_b" "status"
  [ "$status" -eq 0 ]
  [ "$output" = "planning" ]

  # scope_a should be complete
  run tracker_get_field "scope_a" "status"
  [ "$status" -eq 0 ]
  [ "$output" = "complete" ]
}

@test "reading nonexistent scope returns empty" {
  run tracker_read_scope "ghost_scope"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "reading from nonexistent file returns empty" {
  export TRACKER_FILE="${TEST_DIR}/nope/not-here.jsonl"
  run tracker_read_scope "anything"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ─────────────────────────────────────────────
# Atomic write behavior
# ─────────────────────────────────────────────

@test "atomic write uses temp file" {
  # Write a scope and verify no .tmp file lingers after completion
  local json='{"scope":"atomic_test","status":"planning","current_iteration":"iteration_01","iterations":{},"ts":"2026-04-01T10:00:00Z"}'
  tracker_write_scope "atomic_test" "$json"

  # The .tmp file should be gone — it got mv'd to the real file
  [ ! -f "${TRACKER_FILE}.tmp" ]
  # The real file should exist
  [ -f "$TRACKER_FILE" ]
}

@test "atomic write creates parent directory" {
  export TRACKER_FILE="${TEST_DIR}/deep/nested/dir/tracker.jsonl"
  local json='{"scope":"nested","status":"planning","current_iteration":"iteration_01","iterations":{},"ts":"2026-04-01T10:00:00Z"}'
  tracker_write_scope "nested" "$json"

  [ -f "$TRACKER_FILE" ]
  run tracker_read_scope "nested"
  echo "$output" | grep -q '"scope":"nested"'
}

# ─────────────────────────────────────────────
# tracker_get_field
# ─────────────────────────────────────────────

@test "get_field returns correct values" {
  local json='{"scope":"field_test","status":"executing","current_iteration":"iteration_02","iterations":{},"ts":"2026-04-01T12:00:00Z","gh_issue":42}'
  tracker_write_scope "field_test" "$json"

  run tracker_get_field "field_test" "status"
  [ "$output" = "executing" ]

  run tracker_get_field "field_test" "current_iteration"
  [ "$output" = "iteration_02" ]

  run tracker_get_field "field_test" "ts"
  [ "$output" = "2026-04-01T12:00:00Z" ]
}

@test "get_field on nonexistent scope returns empty" {
  run tracker_get_field "no_such_scope" "status"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "get_field with missing arguments fails" {
  run tracker_get_field
  [ "$status" -eq 1 ]
}

# ─────────────────────────────────────────────
# events_log
# ─────────────────────────────────────────────

@test "events_log creates log file and writes valid event" {
  events_log "my_scope" "SCOPE_START" "iteration=iteration_01"

  local log_file="${EVENTS_DIR}/my_scope/scope-events.log"
  [ -f "$log_file" ]

  # Should have exactly one line
  local count
  count=$(wc -l < "$log_file" | tr -d ' ')
  [ "$count" -eq 1 ]

  # Line should contain the right pieces
  grep -q "SCOPE_START" "$log_file"
  grep -q "scope=my_scope" "$log_file"
  grep -q "iteration=iteration_01" "$log_file"
}

@test "events_log appends multiple events" {
  events_log "multi" "SCOPE_START" "iteration=iteration_01"
  events_log "multi" "WU_CREATE" "wu=WU-001" 'desc="Schema migration"'
  events_log "multi" "WU_UPDATE" "wu=WU-001" "status=complete"

  local log_file="${EVENTS_DIR}/multi/scope-events.log"
  local count
  count=$(wc -l < "$log_file" | tr -d ' ')
  [ "$count" -eq 3 ]
}

@test "events_log rejects invalid event type" {
  run events_log "bad_scope" "INVALID_TYPE"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "invalid event type"
}

@test "events_log rejects missing arguments" {
  run events_log
  [ "$status" -eq 1 ]

  run events_log "only_scope"
  [ "$status" -eq 1 ]
}

# ─────────────────────────────────────────────
# Contract validator integration
# ─────────────────────────────────────────────

@test "validator passes on well-formed event log" {
  events_log "valid_scope" "SCOPE_START" "iteration=iteration_01"
  events_log "valid_scope" "ITERATION_START" "iteration=iteration_01"
  events_log "valid_scope" "WU_CREATE" "wu=WU-001" "desc=setup"
  events_log "valid_scope" "WU_UPDATE" "wu=WU-001" "status=complete"
  events_log "valid_scope" "ITERATION_CLOSE" "iteration=iteration_01" "decision=APPROVE"
  events_log "valid_scope" "SCOPE_CLOSE" "reason=approved"

  run bash "$ORIG_DIR/$VALIDATOR" "${EVENTS_DIR}/valid_scope/scope-events.log"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "PASS"
}

@test "validator catches SCOPE_CLOSE before SCOPE_START" {
  # Manually write a bad log — can't use events_log for lifecycle violations
  local log_file="${EVENTS_DIR}/bad_lifecycle/scope-events.log"
  mkdir -p "${EVENTS_DIR}/bad_lifecycle"
  echo "2026-04-01T10:00:00Z SCOPE_CLOSE scope=bad_lifecycle reason=oops" > "$log_file"

  run bash "$ORIG_DIR/$VALIDATOR" "$log_file"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "SCOPE_CLOSE without SCOPE_START"
}

@test "validator catches invalid event type" {
  local log_file="${EVENTS_DIR}/bad_type/scope-events.log"
  mkdir -p "${EVENTS_DIR}/bad_type"
  echo "2026-04-01T10:00:00Z BOGUS_EVENT scope=bad_type" > "$log_file"

  run bash "$ORIG_DIR/$VALIDATOR" "$log_file"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Invalid event type"
}

@test "validator catches missing timestamp" {
  local log_file="${EVENTS_DIR}/no_ts/scope-events.log"
  mkdir -p "${EVENTS_DIR}/no_ts"
  echo "not-a-date SCOPE_START scope=no_ts" > "$log_file"

  run bash "$ORIG_DIR/$VALIDATOR" "$log_file"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Invalid timestamp"
}

@test "validator catches events after SCOPE_CLOSE" {
  local log_file="${EVENTS_DIR}/post_close/scope-events.log"
  mkdir -p "${EVENTS_DIR}/post_close"
  cat > "$log_file" << 'EOF'
2026-04-01T10:00:00Z SCOPE_START scope=post_close iteration=iteration_01
2026-04-01T11:00:00Z SCOPE_CLOSE scope=post_close reason=done
2026-04-01T12:00:00Z WU_CREATE scope=post_close wu=WU-999
EOF

  run bash "$ORIG_DIR/$VALIDATOR" "$log_file"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "after SCOPE_CLOSE"
}
