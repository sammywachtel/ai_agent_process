#!/usr/bin/env bats
# test-github-issues-lifecycle.bats — Unit tests for github-issues-lifecycle.sh
#
# Mock strategy: PATH override — a fake `gh` in $TEST_DIR/bin/ logs every call
# to gh_calls.log and returns configurable output based on command patterns.
# Same approach as test-beads-lifecycle.bats with its bd mock.

SCRIPT="scripts/github-issues-lifecycle.sh"

setup() {
  export TEST_DIR="$(mktemp -d)"
  export ORIG_DIR="$(pwd)"

  # Project structure the script expects
  mkdir -p "$TEST_DIR/.agent_process/work"
  mkdir -p "$TEST_DIR/scripts/lib"

  # Copy the script under test and its dependency
  cp "$ORIG_DIR/$SCRIPT" "$TEST_DIR/scripts/github-issues-lifecycle.sh"
  cp "$ORIG_DIR/scripts/lib/tracker-utils.sh" "$TEST_DIR/scripts/lib/tracker-utils.sh"

  # Point tracker-utils at our temp dir
  export TRACKER_FILE="$TEST_DIR/.agent_process/work/scope-tracker.jsonl"
  export EVENTS_DIR="$TEST_DIR/.agent_process/work"

  # Default config: GH enabled
  cat > "$TEST_DIR/.agent_process/quality-config.json" << 'EOF'
{
  "github_issues": {
    "enabled": true,
    "repo": "test-owner/test-repo"
  }
}
EOF

  # Set up mock gh directory
  mkdir -p "$TEST_DIR/bin"
  export GH_CALLS_LOG="$TEST_DIR/bin/gh_calls.log"

  # Default mock gh — succeeds for everything, logs calls
  _write_mock_gh "default"

  cd "$TEST_DIR"
}

teardown() {
  cd "$ORIG_DIR"
  # Restore PATH before cleanup in case a test clobbered it
  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  rm -rf "$TEST_DIR"
}

# --- Mock gh generator ---
# Writes a mock gh script. Pass a mode to customize behavior.
_write_mock_gh() {
  local mode="${1:-default}"
  cat > "$TEST_DIR/bin/gh" << 'BASEMOCK'
#!/usr/bin/env bash
# Mock gh — logs calls and returns configurable output
echo "$@" >> "$GH_CALLS_LOG"
BASEMOCK

  case "$mode" in
    default)
      cat >> "$TEST_DIR/bin/gh" << 'EOF'
# Default: succeed for everything
case "$*" in
  *"--version"*)
    echo "gh version 2.50.0 (2024-05-01)" ;;
  *"auth status"*)
    echo "Logged in to github.com as testuser" ;;
  *"repo view"*)
    echo '{"name":"test-repo"}' ;;
  *"issue list"*"WU-"*|*"issue list"*"wu-"*)
    # WU search — return a mock sub-issue
    echo '[{"number":55,"title":"WU-01: Some task"}]' ;;
  *"issue list"*"ap:scope"*)
    # Scope search — no existing issue by default
    echo '[]' ;;
  *"issue list"*)
    echo '[]' ;;
  *"issue create"*)
    echo "https://github.com/test-owner/test-repo/issues/42" ;;
  *"issue close"*)
    echo "Closed issue" ;;
  *"issue comment"*)
    echo "Comment added" ;;
  *"issue view"*)
    echo '{"state":"OPEN","labels":[{"name":"ap:scope"}],"title":"my-scope"}' ;;
  *"issue edit"*)
    echo "Issue edited" ;;
  *"label list"*)
    echo "ap:scope" ;;
  *"label create"*)
    echo "Label created" ;;
  *"api"*"sub_issues"*)
    echo '{"id": 99, "content_type": "Issue"}' ;;
  *)
    echo "mock-gh-ok" ;;
esac
exit 0
EOF
      ;;

    existing-issue)
      cat >> "$TEST_DIR/bin/gh" << 'EOF'
case "$*" in
  *"--version"*)
    echo "gh version 2.50.0 (2024-05-01)" ;;
  *"auth status"*)
    echo "Logged in to github.com as testuser" ;;
  *"issue list"*"ap:scope"*)
    echo '[{"number":17,"title":"my-scope"}]' ;;
  *"label list"*)
    echo "ap:scope" ;;
  *"label create"*)
    echo "Label created" ;;
  *"repo view"*)
    echo '{"name":"test-repo"}' ;;
  *)
    echo "mock-gh-ok" ;;
esac
exit 0
EOF
      ;;

    version-old)
      cat >> "$TEST_DIR/bin/gh" << 'EOF'
case "$*" in
  *"--version"*)
    echo "gh version 2.10.0 (2022-01-01)" ;;
  *)
    echo "mock" ;;
esac
exit 0
EOF
      ;;

    auth-fail)
      cat >> "$TEST_DIR/bin/gh" << 'EOF'
case "$*" in
  *"--version"*)
    echo "gh version 2.50.0 (2024-05-01)" ;;
  *"auth status"*)
    echo "You are not logged in" >&2
    exit 1 ;;
  *)
    echo "mock" ;;
esac
exit 0
EOF
      ;;

    repo-fail)
      cat >> "$TEST_DIR/bin/gh" << 'EOF'
case "$*" in
  *"--version"*)
    echo "gh version 2.50.0 (2024-05-01)" ;;
  *"auth status"*)
    echo "Logged in to github.com as testuser" ;;
  *"repo view"*)
    echo "Could not resolve to a Repository" >&2
    exit 1 ;;
  *)
    echo "mock" ;;
esac
exit 0
EOF
      ;;

    transient-502)
      # First call to issue create returns 502, second succeeds
      cat >> "$TEST_DIR/bin/gh" << 'EOF'
case "$*" in
  *"--version"*)
    echo "gh version 2.50.0 (2024-05-01)" ;;
  *"auth status"*)
    echo "Logged in" ;;
  *"issue list"*)
    echo '[]' ;;
  *"issue create"*)
    # Check if this is a retry (second call)
    COUNT=$(grep -c "issue create" "$GH_CALLS_LOG" 2>/dev/null || echo "0")
    if [ "$COUNT" -le 1 ]; then
      echo "502 Bad Gateway" >&2
      exit 1
    else
      echo "https://github.com/test-owner/test-repo/issues/42"
      exit 0
    fi
    ;;
  *"label list"*)
    echo "ap:scope" ;;
  *"label create"*)
    echo "Label created" ;;
  *"repo view"*)
    echo '{"name":"test-repo"}' ;;
  *)
    echo "mock-ok" ;;
esac
exit 0
EOF
      ;;

    permanent-401)
      cat >> "$TEST_DIR/bin/gh" << 'EOF'
case "$*" in
  *"--version"*)
    echo "gh version 2.50.0 (2024-05-01)" ;;
  *"auth status"*)
    echo "Logged in" ;;
  *"issue list"*)
    echo '[]' ;;
  *"issue create"*)
    echo "401 Unauthorized: Bad credentials" >&2
    exit 1
    ;;
  *"label list"*)
    echo "ap:scope" ;;
  *"label create"*)
    echo "Label created" ;;
  *"repo view"*)
    echo '{"name":"test-repo"}' ;;
  *)
    echo "mock-ok" ;;
esac
exit 0
EOF
      ;;

    gh-create-fail)
      cat >> "$TEST_DIR/bin/gh" << 'EOF'
case "$*" in
  *"--version"*)
    echo "gh version 2.50.0 (2024-05-01)" ;;
  *"auth status"*)
    echo "Logged in" ;;
  *"issue list"*)
    echo '[]' ;;
  *"issue create"*)
    echo "Something went horribly wrong" >&2
    exit 1
    ;;
  *"label list"*)
    echo "ap:scope" ;;
  *"label create"*)
    echo "Label created" ;;
  *"repo view"*)
    echo '{"name":"test-repo"}' ;;
  *)
    echo "mock-ok" ;;
esac
exit 0
EOF
      ;;
  esac

  chmod +x "$TEST_DIR/bin/gh"
}

# Helper: count how many times gh was called
_gh_call_count() {
  if [ -f "$GH_CALLS_LOG" ]; then
    wc -l < "$GH_CALLS_LOG" | tr -d ' '
  else
    echo "0"
  fi
}

# Helper: check if a specific gh subcommand was called
_gh_was_called_with() {
  local pattern="$1"
  grep -q "$pattern" "$GH_CALLS_LOG" 2>/dev/null
}

# ============================================================
#  health-check tests
# ============================================================

@test "health-check: gh not installed → exit 1 with install hint" {
  # Create a minimal PATH that has jq but not gh
  mkdir -p "$TEST_DIR/nogh-bin"
  # Symlink essential tools but NOT gh
  for cmd in jq bash env date mkdir cat wc grep sed head cut tr rm mv; do
    local cmd_path
    cmd_path=$(command -v "$cmd" 2>/dev/null) && ln -sf "$cmd_path" "$TEST_DIR/nogh-bin/$cmd" 2>/dev/null || true
  done
  export PATH="$TEST_DIR/nogh-bin"
  run bash scripts/github-issues-lifecycle.sh health-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh"* ]]
  [[ "$output" == *"install"* ]] || [[ "$output" == *"Install"* ]] || [[ "$output" == *"not found"* ]]
}

@test "health-check: gh version too old → exit 1 with minimum version" {
  _write_mock_gh "version-old"
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh health-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"2.20.0"* ]]
}

@test "health-check: gh not authenticated → exit 1 with auth hint" {
  _write_mock_gh "auth-fail"
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh health-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"auth"* ]]
}

@test "health-check: repo inaccessible → exit 1 with repo name" {
  _write_mock_gh "repo-fail"
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh health-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"test-owner/test-repo"* ]]
}

@test "health-check: all pass → exit 0" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh health-check
  [ "$status" -eq 0 ]
}

# ============================================================
#  start tests
# ============================================================

@test "start: GH disabled → writes tracker only, no gh calls" {
  cat > "$TEST_DIR/.agent_process/quality-config.json" << 'EOF'
{"github_issues": {"enabled": false, "repo": "test-owner/test-repo"}}
EOF
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  # Tracker should have a record
  [ -f "$TRACKER_FILE" ]
  grep -q '"scope":"my-scope"' "$TRACKER_FILE"

  # No gh calls made
  [ "$(_gh_call_count)" -eq 0 ]
}

@test "start: GH disabled when config missing → writes tracker only" {
  rm -f "$TEST_DIR/.agent_process/quality-config.json"
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  [ -f "$TRACKER_FILE" ]
  grep -q '"scope":"my-scope"' "$TRACKER_FILE"
  [ "$(_gh_call_count)" -eq 0 ]
}

@test "start: no existing issue → creates issue, writes tracker with gh_issue" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  # Tracker should have gh_issue number
  grep -q '"gh_issue"' "$TRACKER_FILE"
  grep -q '"my-scope"' "$TRACKER_FILE"

  # gh issue create was called
  _gh_was_called_with "issue create"

  # --repo was used
  _gh_was_called_with "test-owner/test-repo"
}

@test "start: existing issue → reuses issue number, no create" {
  _write_mock_gh "existing-issue"
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  # Tracker should have the existing issue number (17)
  grep -q '"gh_issue":"17"' "$TRACKER_FILE" || grep -q '"gh_issue":17' "$TRACKER_FILE"

  # issue create should NOT have been called
  ! _gh_was_called_with "issue create"
}

@test "start: gh fails → HALT but local state still written" {
  _write_mock_gh "gh-create-fail"
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh start my-scope
  # Script should indicate failure (non-zero or HALT message)
  # But local tracker state should still exist
  [ -f "$TRACKER_FILE" ]
  grep -q '"scope":"my-scope"' "$TRACKER_FILE"

  # Events log should have the start event
  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  [ -f "$events_file" ]
  grep -q "SCOPE_START" "$events_file"
}

@test "start: invalid scope name → rejected before any I/O" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh start "foo;rm -rf /"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid scope"* ]]

  # No tracker file created
  [ ! -f "$TRACKER_FILE" ]
  # No gh calls
  [ "$(_gh_call_count)" -eq 0 ]
}

@test "start: scope with spaces rejected" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh start "bad scope name"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid scope"* ]]
}

@test "start: scope with dots rejected" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh start "bad.scope"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid scope"* ]]
}

@test "start: valid scope names accepted" {
  cat > "$TEST_DIR/.agent_process/quality-config.json" << 'EOF'
{"github_issues": {"enabled": false}}
EOF
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start "auth_middleware-01"
  [ "$status" -eq 0 ]

  run bash scripts/github-issues-lifecycle.sh start "MyScope2"
  [ "$status" -eq 0 ]
}

# ============================================================
#  set-iteration / get-iteration tests
# ============================================================

@test "set-iteration + get-iteration: round-trip returns same value" {
  export PATH="$TEST_DIR/bin:$PATH"
  # Start scope first
  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  run bash scripts/github-issues-lifecycle.sh set-iteration my-scope iteration_03
  [ "$status" -eq 0 ]

  run bash scripts/github-issues-lifecycle.sh get-iteration my-scope
  [ "$status" -eq 0 ]
  [[ "$output" == *"iteration_03"* ]]
}

@test "set-iteration: GH disabled → tracker only, no gh calls" {
  cat > "$TEST_DIR/.agent_process/quality-config.json" << 'EOF'
{"github_issues": {"enabled": false}}
EOF
  export PATH="$TEST_DIR/bin:$PATH"

  # Start scope first (creates tracker entry)
  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  # Reset gh call log
  > "$GH_CALLS_LOG"

  run bash scripts/github-issues-lifecycle.sh set-iteration my-scope iteration_02
  [ "$status" -eq 0 ]
  [ "$(_gh_call_count)" -eq 0 ]

  run bash scripts/github-issues-lifecycle.sh get-iteration my-scope
  [ "$status" -eq 0 ]
  [[ "$output" == *"iteration_02"* ]]
}

@test "get-iteration: scope not in tracker → error" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh get-iteration nonexistent-scope
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "set-iteration: scope not in tracker → error" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh set-iteration nonexistent-scope iteration_01
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# ============================================================
#  task-create tests
# ============================================================

@test "task-create: creates sub-issue via gh api" {
  export PATH="$TEST_DIR/bin:$PATH"

  # Start scope first
  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  run bash scripts/github-issues-lifecycle.sh task-create my-scope WU-01 "Implement the thing"
  [ "$status" -eq 0 ]

  # Should have called gh issue create for the child
  _gh_was_called_with "issue create"

  # Should have called gh api for sub_issues linkage
  _gh_was_called_with "sub_issues"

  # Events log should record WU_CREATE
  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "WU_CREATE" "$events_file"
  grep -q "WU-01" "$events_file"
}

@test "task-create: GH disabled → events log only, no gh calls" {
  cat > "$TEST_DIR/.agent_process/quality-config.json" << 'EOF'
{"github_issues": {"enabled": false}}
EOF
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]
  > "$GH_CALLS_LOG"

  run bash scripts/github-issues-lifecycle.sh task-create my-scope WU-01 "Implement feature"
  [ "$status" -eq 0 ]

  [ "$(_gh_call_count)" -eq 0 ]

  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "WU_CREATE" "$events_file"
}

@test "task-create: validates WU ID format" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  # Valid WU ID
  run bash scripts/github-issues-lifecycle.sh task-create my-scope WU-01 "Good task"
  [ "$status" -eq 0 ]

  # Invalid WU ID (shell injection attempt)
  run bash scripts/github-issues-lifecycle.sh task-create my-scope "WU;rm -rf /" "Bad task"
  [ "$status" -ne 0 ]
}

# ============================================================
#  task-update tests
# ============================================================

@test "task-update: complete → closes sub-issue" {
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  # Create a task first so tracker has the WU mapping
  run bash scripts/github-issues-lifecycle.sh task-create my-scope WU-01 "Some task"
  [ "$status" -eq 0 ]

  run bash scripts/github-issues-lifecycle.sh task-update my-scope WU-01 complete
  [ "$status" -eq 0 ]

  # Should have called gh issue close
  _gh_was_called_with "issue close"

  # Events log should record WU_UPDATE
  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "WU_UPDATE" "$events_file"
  grep -q "complete" "$events_file"
}

@test "task-update: blocked → adds label" {
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  run bash scripts/github-issues-lifecycle.sh task-create my-scope WU-01 "Some task"

  run bash scripts/github-issues-lifecycle.sh task-update my-scope WU-01 blocked
  [ "$status" -eq 0 ]

  # Should have called gh issue edit with label
  _gh_was_called_with "issue edit"
  _gh_was_called_with "status:blocked"

  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "WU_UPDATE" "$events_file"
  grep -q "blocked" "$events_file"
}

@test "task-update: GH disabled → events only" {
  cat > "$TEST_DIR/.agent_process/quality-config.json" << 'EOF'
{"github_issues": {"enabled": false}}
EOF
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  run bash scripts/github-issues-lifecycle.sh task-create my-scope WU-01 "Task"
  > "$GH_CALLS_LOG"

  run bash scripts/github-issues-lifecycle.sh task-update my-scope WU-01 complete
  [ "$status" -eq 0 ]
  [ "$(_gh_call_count)" -eq 0 ]

  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "WU_UPDATE" "$events_file"
}

# ============================================================
#  close tests
# ============================================================

@test "close: approved → closes issue + status:approved label" {
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  run bash scripts/github-issues-lifecycle.sh close my-scope approved
  [ "$status" -eq 0 ]

  _gh_was_called_with "issue close"
  _gh_was_called_with "issue edit"
  _gh_was_called_with "status:approved"

  # Tracker should show closed status
  grep -q '"status":"closed"' "$TRACKER_FILE" || grep -q '"status":"approved"' "$TRACKER_FILE"

  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "SCOPE_CLOSE" "$events_file"
  grep -q "approved" "$events_file"
}

@test "close: blocked → closes issue + status:blocked label" {
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope

  run bash scripts/github-issues-lifecycle.sh close my-scope blocked
  [ "$status" -eq 0 ]

  _gh_was_called_with "issue close"
  _gh_was_called_with "status:blocked"

  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "SCOPE_CLOSE" "$events_file"
  grep -q "blocked" "$events_file"
}

@test "close: GH disabled → tracker update only" {
  cat > "$TEST_DIR/.agent_process/quality-config.json" << 'EOF'
{"github_issues": {"enabled": false}}
EOF
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  > "$GH_CALLS_LOG"

  run bash scripts/github-issues-lifecycle.sh close my-scope approved
  [ "$status" -eq 0 ]
  [ "$(_gh_call_count)" -eq 0 ]

  # Tracker updated
  grep -q '"status":"closed"' "$TRACKER_FILE" || grep -q '"status":"approved"' "$TRACKER_FILE"

  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "SCOPE_CLOSE" "$events_file"
}

# ============================================================
#  verify tests
# ============================================================

@test "verify: compares issue state with local events" {
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  run bash scripts/github-issues-lifecycle.sh verify my-scope
  [ "$status" -eq 0 ]
  # Should produce some verification output
  [[ "$output" == *"my-scope"* ]]

  # Should have called gh issue view when GH is enabled
  _gh_was_called_with "issue view"
}

# ============================================================
#  comment tests
# ============================================================

@test "comment: adds comment to issue when GH enabled" {
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope

  run bash scripts/github-issues-lifecycle.sh comment my-scope "Iteration 2 starting"
  [ "$status" -eq 0 ]

  _gh_was_called_with "issue comment"
  _gh_was_called_with "test-owner/test-repo"

  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "COMMENT" "$events_file"
}

@test "comment: GH disabled → events log only" {
  cat > "$TEST_DIR/.agent_process/quality-config.json" << 'EOF'
{"github_issues": {"enabled": false}}
EOF
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  > "$GH_CALLS_LOG"

  run bash scripts/github-issues-lifecycle.sh comment my-scope "Just a note"
  [ "$status" -eq 0 ]
  [ "$(_gh_call_count)" -eq 0 ]

  local events_file="$EVENTS_DIR/my-scope/scope-events.log"
  grep -q "COMMENT" "$events_file"
}

# ============================================================
#  Transient retry tests
# ============================================================

@test "transient retry: 502 on first call, succeeds on retry" {
  _write_mock_gh "transient-502"
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  # issue create should have been called twice (initial + retry)
  local create_count
  create_count=$(grep -c "issue create" "$GH_CALLS_LOG" 2>/dev/null || echo "0")
  [ "$create_count" -ge 2 ]

  # Tracker should have the issue number from the retry
  grep -q '"gh_issue"' "$TRACKER_FILE"
}

@test "transient retry: 401 → no retry, immediate HALT" {
  _write_mock_gh "permanent-401"
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope

  # issue create should have been called exactly once (no retry for 401)
  local create_count
  create_count=$(grep -c "issue create" "$GH_CALLS_LOG" 2>/dev/null || echo "0")
  [ "$create_count" -eq 1 ]

  # Output should mention HALT
  [[ "$output" == *"HALT"* ]] || [[ "$output" == *"halt"* ]] || [[ "$output" == *"401"* ]]

  # But local state should still be written
  [ -f "$TRACKER_FILE" ]
  grep -q '"scope":"my-scope"' "$TRACKER_FILE"
}

# ============================================================
#  Edge cases
# ============================================================

@test "no args → usage message and exit 1" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

@test "unknown action → error" {
  export PATH="$TEST_DIR/bin:$PATH"
  run bash scripts/github-issues-lifecycle.sh bogus my-scope
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown action"* ]]
}

@test "--repo flag used on every gh command" {
  export PATH="$TEST_DIR/bin:$PATH"

  run bash scripts/github-issues-lifecycle.sh start my-scope
  [ "$status" -eq 0 ]

  # Every gh call that isn't --version or auth status should have --repo
  while IFS= read -r line; do
    # Skip version checks, auth checks, and api calls (api uses repos/ path instead)
    if [[ "$line" == *"--version"* ]] || [[ "$line" == *"auth status"* ]] || [[ "$line" == *"api "* ]]; then
      continue
    fi
    # All other gh commands must have --repo
    [[ "$line" == *"--repo"* ]] || fail "gh command missing --repo: $line"
  done < "$GH_CALLS_LOG"
}
