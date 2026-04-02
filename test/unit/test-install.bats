#!/usr/bin/env bats
# test-install.bats — Unit tests for install.sh
#
# Tests installation into a fresh target and reinstall preservation.

INSTALL_SCRIPT="install.sh"

setup() {
  export TEST_DIR="$(mktemp -d)"
  export SOURCE_DIR="$(pwd)"
  export TARGET_DIR="$TEST_DIR/target-project"

  # Create a minimal target project
  mkdir -p "$TARGET_DIR"
  cd "$TARGET_DIR"
  git init -q
  echo "# Test Project" > README.md
  git add . && git commit -q -m "init"
}

teardown() {
  cd "$SOURCE_DIR"
  rm -rf "$TEST_DIR"
}


# Helper: run install.sh targeting our temp project
# install.sh determines source from BASH_SOURCE[0], target from $1 or pwd
run_install() {
  echo "n" | bash "$SOURCE_DIR/$INSTALL_SCRIPT" "$TARGET_DIR" 2>/dev/null || true
}

@test "fresh install creates .agent_process directory" {
  run_install
  [ -d "$TARGET_DIR/.agent_process" ]
}

@test "fresh install creates required subdirectories" {
  run_install
  [ -d "$TARGET_DIR/.agent_process/work" ]
  [ -d "$TARGET_DIR/.agent_process/knowledge" ]
  # roadmap/ and requirements_docs/ are created by /ap_project init, not install.sh
  # install.sh creates the core execution infrastructure
}

@test "fresh install creates quality-config.json" {
  run_install
  [ -f "$TARGET_DIR/.agent_process/quality-config.json" ]
  python3 -c "import json; json.load(open('$TARGET_DIR/.agent_process/quality-config.json'))"
}

@test "fresh install copies commands to .claude/commands" {
  run_install
  [ -d "$TARGET_DIR/.claude/commands" ]
  ls "$TARGET_DIR/.claude/commands/"ap_exec* 2>/dev/null | grep -q .
}

@test "fresh install seeds knowledge JSONL files" {
  run_install
  [ -f "$TARGET_DIR/.agent_process/knowledge/patterns.jsonl" ]
  [ -f "$TARGET_DIR/.agent_process/knowledge/gotchas.jsonl" ]
  [ -f "$TARGET_DIR/.agent_process/knowledge/decisions.jsonl" ]
  [ -f "$TARGET_DIR/.agent_process/knowledge/anti-patterns.jsonl" ]
}

@test "reinstall preserves existing work directory" {
  run_install

  # Create some work artifacts
  mkdir -p "$TARGET_DIR/.agent_process/work/test-scope/iteration_01"
  echo "# Results" > "$TARGET_DIR/.agent_process/work/test-scope/iteration_01/results.md"

  # Reinstall
  run_install

  [ -f "$TARGET_DIR/.agent_process/work/test-scope/iteration_01/results.md" ]
}

@test "reinstall preserves existing knowledge files" {
  run_install

  echo '{"scope":"test","type":"pattern","content":"test entry"}' >> "$TARGET_DIR/.agent_process/knowledge/patterns.jsonl"
  LINES_BEFORE=$(wc -l < "$TARGET_DIR/.agent_process/knowledge/patterns.jsonl")

  run_install

  LINES_AFTER=$(wc -l < "$TARGET_DIR/.agent_process/knowledge/patterns.jsonl")
  [ "$LINES_AFTER" -ge "$LINES_BEFORE" ]
}

@test "reinstall preserves quality-config.json with _user_configured flag" {
  run_install

  python3 -c "
import json
with open('$TARGET_DIR/.agent_process/quality-config.json') as f:
    cfg = json.load(f)
cfg['github_issues'] = {'enabled': True, '_user_configured': True, 'repo': 'myorg/myproject'}
with open('$TARGET_DIR/.agent_process/quality-config.json', 'w') as f:
    json.dump(cfg, f, indent=2)
"

  run_install

  python3 -c "
import json
cfg = json.load(open('$TARGET_DIR/.agent_process/quality-config.json'))
assert cfg['github_issues']['enabled'] == True, 'GitHub Issues should still be enabled'
assert cfg['github_issues']['repo'] == 'myorg/myproject', 'Repo should be preserved'
"
}
