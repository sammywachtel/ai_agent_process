#!/usr/bin/env bats
# test-beads-lifecycle.bats — Unit tests for beads-lifecycle.sh
#
# Tests the script's behavior under various conditions:
# - BEADS disabled → silent exit
# - Config missing → silent exit
# - bd not installed → silent exit
# - Breadcrumb writing
# - Action routing

SCRIPT="scripts/beads-lifecycle.sh"

setup() {
  # Create a temporary workspace for each test
  export TEST_DIR="$(mktemp -d)"
  export ORIG_DIR="$(pwd)"

  # Set up minimal project structure
  mkdir -p "$TEST_DIR/.agent_process/work/test-scope/iteration_01"
  mkdir -p "$TEST_DIR/.agent_process/scripts"

  # Copy the script under test
  cp "$ORIG_DIR/$SCRIPT" "$TEST_DIR/.agent_process/scripts/beads-lifecycle.sh"

  cd "$TEST_DIR"
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR"
}

# --- Silent exit conditions ---

@test "exits 0 with no args" {
  run bash .agent_process/scripts/beads-lifecycle.sh
  [ "$status" -eq 0 ]
}

@test "exits 0 when quality-config.json missing" {
  # No config file at all
  run bash .agent_process/scripts/beads-lifecycle.sh start test-scope
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when BEADS disabled in config" {
  cat > .agent_process/quality-config.json << 'EOF'
{"beads": {"enabled": false}}
EOF
  run bash .agent_process/scripts/beads-lifecycle.sh start test-scope
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when beads not in config at all" {
  echo '{}' > .agent_process/quality-config.json
  run bash .agent_process/scripts/beads-lifecycle.sh start test-scope
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when bd command not found" {
  cat > .agent_process/quality-config.json << 'EOF'
{"beads": {"enabled": true}}
EOF
  # Ensure bd is not in PATH for this test
  export PATH="/usr/bin:/bin"
  run bash .agent_process/scripts/beads-lifecycle.sh start test-scope
  [ "$status" -eq 0 ]
}

# --- Breadcrumb writing ---
# These tests mock bd (not available in CI) but verify breadcrumb behavior

@test "start action writes EPIC_START breadcrumb" {
  cat > .agent_process/quality-config.json << 'EOF'
{"beads": {"enabled": true}}
EOF

  # Create a fake bd that succeeds
  mkdir -p "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/bd" << 'MOCK'
#!/bin/bash
# Mock bd — returns empty for queries, fake ID for creates
case "$1" in
  query) echo "[]" ;;
  create) echo "mock-epic-123" ;;
  *) echo "mock" ;;
esac
MOCK
  chmod +x "$TEST_DIR/bin/bd"
  export PATH="$TEST_DIR/bin:$PATH"

  run bash .agent_process/scripts/beads-lifecycle.sh start test-scope
  [ "$status" -eq 0 ]

  # Check breadcrumb was written
  [ -f ".agent_process/work/test-scope/.beads-state" ]
  grep -q "^EPIC_START=" ".agent_process/work/test-scope/.beads-state"
}

@test "close action writes EPIC_CLOSE breadcrumb with label" {
  cat > .agent_process/quality-config.json << 'EOF'
{"beads": {"enabled": true}}
EOF

  mkdir -p "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/bd" << 'MOCK'
#!/bin/bash
case "$1" in
  query) echo '[{"id": "mock-epic-123"}]' ;;
  close) echo "closed" ;;
  *) echo "mock" ;;
esac
MOCK
  chmod +x "$TEST_DIR/bin/bd"
  export PATH="$TEST_DIR/bin:$PATH"

  run bash .agent_process/scripts/beads-lifecycle.sh close test-scope approved
  [ "$status" -eq 0 ]

  [ -f ".agent_process/work/test-scope/.beads-state" ]
  grep -q "EPIC_CLOSE=.*approved" ".agent_process/work/test-scope/.beads-state"
}

@test "task-create writes TASK_CREATE breadcrumb" {
  cat > .agent_process/quality-config.json << 'EOF'
{"beads": {"enabled": true}}
EOF

  mkdir -p "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/bd" << 'MOCK'
#!/bin/bash
case "$1" in
  query) echo '[{"id": "mock-epic-123"}]' ;;
  create) echo "mock-task-456" ;;
  *) echo "mock" ;;
esac
MOCK
  chmod +x "$TEST_DIR/bin/bd"
  export PATH="$TEST_DIR/bin:$PATH"

  run bash .agent_process/scripts/beads-lifecycle.sh task-create test-scope WU-01 "Implement feature"
  [ "$status" -eq 0 ]

  [ -f ".agent_process/work/test-scope/.beads-state" ]
  grep -q "TASK_CREATE=.*WU-01" ".agent_process/work/test-scope/.beads-state"
}

@test "verify action reports missing state file" {
  cat > .agent_process/quality-config.json << 'EOF'
{"beads": {"enabled": true}}
EOF

  # Mock bd (verify doesn't call bd, but needs enabled check)
  mkdir -p "$TEST_DIR/bin"
  echo '#!/bin/bash' > "$TEST_DIR/bin/bd"
  chmod +x "$TEST_DIR/bin/bd"
  export PATH="$TEST_DIR/bin:$PATH"

  run bash .agent_process/scripts/beads-lifecycle.sh verify test-scope iteration_01
  [ "$status" -eq 0 ]
  [[ "$output" == *"No .beads-state file"* ]]
}

@test "verify action reads existing breadcrumbs" {
  cat > .agent_process/quality-config.json << 'EOF'
{"beads": {"enabled": true}}
EOF

  mkdir -p "$TEST_DIR/bin"
  echo '#!/bin/bash' > "$TEST_DIR/bin/bd"
  chmod +x "$TEST_DIR/bin/bd"
  export PATH="$TEST_DIR/bin:$PATH"

  # Pre-populate breadcrumbs
  echo "EPIC_START=2026-03-24T10:00:00 test-scope" > .agent_process/work/test-scope/iteration_01/.beads-state
  echo "EPIC_CREATED=2026-03-24T10:00:01 success:mock-123" >> .agent_process/work/test-scope/iteration_01/.beads-state

  run bash .agent_process/scripts/beads-lifecycle.sh verify test-scope iteration_01
  [ "$status" -eq 0 ]
  [[ "$output" == *"Epic lifecycle: started and created"* ]]
}

# --- Unknown action handling ---

@test "unknown action doesn't crash" {
  cat > .agent_process/quality-config.json << 'EOF'
{"beads": {"enabled": true}}
EOF

  mkdir -p "$TEST_DIR/bin"
  echo '#!/bin/bash' > "$TEST_DIR/bin/bd"
  chmod +x "$TEST_DIR/bin/bd"
  export PATH="$TEST_DIR/bin:$PATH"

  run bash .agent_process/scripts/beads-lifecycle.sh bogus test-scope
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unknown action"* ]]
}
