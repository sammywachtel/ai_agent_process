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

@test "duplicate scope entries return single value" {
  # Manually create a tracker file with duplicate scope entries (simulating corruption)
  cat > "$TRACKER_FILE" << 'EOF'
{"scope":"dup_scope","status":"planning","gh_issue":"135"}
{"scope":"dup_scope","status":"executing","gh_issue":"135"}
EOF

  # tracker_read_scope should return only ONE line, not both
  run tracker_read_scope "dup_scope"
  [ "$status" -eq 0 ]
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$line_count" -eq 1 ]

  # tracker_get_field should return a clean single value, not "135\n135"
  run tracker_get_field "dup_scope" "gh_issue"
  [ "$status" -eq 0 ]
  [ "$output" = "135" ]
  # Verify no embedded newlines
  [[ "$output" != *$'\n'* ]]
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

# ─────────────────────────────────────────────
# High-level scope operations
# ─────────────────────────────────────────────

@test "scope_start creates new scope in tracker" {
  run scope_start "new_scope"
  [ "$status" -eq 0 ]

  # Should have created tracker entry
  run tracker_read_scope "new_scope"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"scope":"new_scope"'
  echo "$output" | grep -q '"status":"active"'
  echo "$output" | grep -q '"iteration":"iteration_01"'

  # Should have logged SCOPE_START event
  local log_file="${EVENTS_DIR}/new_scope/scope-events.log"
  [ -f "$log_file" ]
  grep -q "SCOPE_START" "$log_file"
}

@test "scope_start adopts existing scope" {
  # Create a scope first
  local json='{"scope":"existing_scope","status":"planning","iteration":"iteration_02","created":"2026-04-01T10:00:00Z"}'
  tracker_write_scope "existing_scope" "$json"

  # scope_start should adopt it, return existing iteration
  run scope_start "existing_scope"
  [ "$status" -eq 0 ]
  [ "$output" = "iteration_02" ]

  # Should have logged SCOPE_ADOPT event
  local log_file="${EVENTS_DIR}/existing_scope/scope-events.log"
  [ -f "$log_file" ]
  grep -q "SCOPE_ADOPT" "$log_file"
}

@test "scope_start updates current_iteration.conf" {
  scope_start "conf_test"

  local conf_file="${EVENTS_DIR}/current_iteration.conf"
  [ -f "$conf_file" ]
  grep -q "SCOPE=conf_test" "$conf_file"
  grep -q "ITERATION=iteration_01" "$conf_file"
}

@test "scope_set_status updates tracker" {
  # Create scope first
  scope_start "status_test" >/dev/null

  # Set status
  run scope_set_status "status_test" "executing"
  [ "$status" -eq 0 ]

  # Verify tracker updated
  run tracker_get_field "status_test" "status"
  [ "$output" = "executing" ]
}

@test "scope_set_status strips status: prefix" {
  scope_start "prefix_test" >/dev/null

  # Pass with prefix
  scope_set_status "prefix_test" "status:reviewing"

  # Should store without prefix
  run tracker_get_field "prefix_test" "status"
  [ "$output" = "reviewing" ]
}

@test "scope_set_status logs event" {
  scope_start "event_test" >/dev/null
  scope_set_status "event_test" "planning"

  local log_file="${EVENTS_DIR}/event_test/scope-events.log"
  grep -q "status-change:status:planning" "$log_file"
}

@test "scope_set_status fails for nonexistent scope" {
  run scope_set_status "ghost" "active"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "not found"
}

@test "scope_set_iteration updates tracker and conf" {
  scope_start "iter_test" >/dev/null

  run scope_set_iteration "iter_test" "iteration_02"
  [ "$status" -eq 0 ]

  # Tracker updated
  run tracker_get_field "iter_test" "iteration"
  [ "$output" = "iteration_02" ]

  # current_iteration.conf updated
  local conf_file="${EVENTS_DIR}/current_iteration.conf"
  grep -q "SCOPE=iter_test" "$conf_file"
  grep -q "ITERATION=iteration_02" "$conf_file"
}

@test "scope_set_iteration logs ITERATION_START event" {
  scope_start "iter_log_test" >/dev/null
  scope_set_iteration "iter_log_test" "iteration_01_a"

  local log_file="${EVENTS_DIR}/iter_log_test/scope-events.log"
  grep -q "ITERATION_START" "$log_file"
  grep -q "iteration=iteration_01_a" "$log_file"
}

@test "scope_close marks scope as closed with decision" {
  scope_start "close_test" >/dev/null

  run scope_close "close_test" "approved"
  [ "$status" -eq 0 ]

  # Status should be "closed"
  run tracker_get_field "close_test" "status"
  [ "$output" = "closed" ]

  # Decision should be recorded
  run tracker_get_field "close_test" "decision"
  [ "$output" = "approved" ]
}

@test "scope_close logs SCOPE_CLOSE event" {
  scope_start "close_event_test" >/dev/null
  scope_close "close_event_test" "blocked"

  local log_file="${EVENTS_DIR}/close_event_test/scope-events.log"
  grep -q "SCOPE_CLOSE" "$log_file"
  grep -q "decision=blocked" "$log_file"
}

@test "set_current_scope writes conf file" {
  set_current_scope "manual_scope" "iteration_03"

  local conf_file="${EVENTS_DIR}/current_iteration.conf"
  [ -f "$conf_file" ]
  grep -q "SCOPE=manual_scope" "$conf_file"
  grep -q "ITERATION=iteration_03" "$conf_file"
}

@test "get_current_scope reads conf file" {
  set_current_scope "read_test" "iteration_05"

  run get_current_scope
  [ "$status" -eq 0 ]
  [ "$output" = "read_test iteration_05" ]
}
