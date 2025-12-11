#!/usr/bin/env bash
set -euo pipefail

# Simplified after_edit hook - scoped validation feedback only
# No enforcement, no artifact checking, just fast validation feedback
#
# Note: Claude Code hooks receive JSON context via stdin, not command-line args.
# We read the current scope from current_iteration.conf instead.

# Consume stdin (Claude Code passes JSON context, but we use config file instead)
cat > /dev/null

SCRIPT_DIR=".agent_process/scripts/after_edit"

# Read current scope from iteration config file
CURRENT_SCOPE="unknown"
CURRENT_ITERATION="unknown"
if [[ -f ".agent_process/work/current_iteration.conf" ]]; then
  CURRENT_SCOPE=$(grep "^SCOPE=" ".agent_process/work/current_iteration.conf" | cut -d'=' -f2 || echo "unknown")
  CURRENT_ITERATION=$(grep "^ITERATION=" ".agent_process/work/current_iteration.conf" | cut -d'=' -f2 || echo "unknown")
fi

echo "[hook_after_edit] Running scoped validation for $CURRENT_SCOPE/$CURRENT_ITERATION"

# Only run the validator for the current scope (not all validators)
SCOPE_VALIDATOR="$SCRIPT_DIR/validate-${CURRENT_SCOPE}.sh"

if [[ -f "$SCOPE_VALIDATOR" ]]; then
  echo "[hook_after_edit] Running validator for scope: $CURRENT_SCOPE"
  bash "$SCOPE_VALIDATOR" "$CURRENT_SCOPE" "$CURRENT_ITERATION"
else
  echo "[hook_after_edit] No validator found for scope: $CURRENT_SCOPE"
  echo "[hook_after_edit] Available validators:"
  ls -1 "$SCRIPT_DIR"/validate-*.sh 2>/dev/null | sed 's/.*validate-//;s/.sh//' | sort || echo "  (none)"
fi

echo "[hook_after_edit] Complete"

# Exit code reflects validation result
# No additional enforcement or artifact checking
