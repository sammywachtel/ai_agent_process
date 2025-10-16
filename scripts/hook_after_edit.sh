#!/usr/bin/env bash
set -euo pipefail

# Simplified after_edit hook - scoped validation feedback only
# No enforcement, no artifact checking, just fast validation feedback

SCOPE=${1:-unknown}
ITERATION=${2:-unknown}

echo "[hook_after_edit] Running scoped validation for $SCOPE/$ITERATION"

# Run scope-specific validation script(s)
SCRIPT_DIR=".agent_process/scripts/after_edit"

if [[ -d "$SCRIPT_DIR" ]]; then
  for script in "$SCRIPT_DIR"/validate-*.sh; do
    [[ -e "$script" ]] || continue
    echo "[hook_after_edit] Running $(basename "$script")"
    bash "$script" "$SCOPE" "$ITERATION"
  done
else
  echo "[hook_after_edit] No validation scripts found in $SCRIPT_DIR"
fi

echo "[hook_after_edit] Complete"

# Exit code reflects validation result
# No additional enforcement or artifact checking
