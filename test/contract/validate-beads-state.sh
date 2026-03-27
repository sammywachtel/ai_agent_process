#!/usr/bin/env bash
# validate-beads-state.sh — Contract validator for .beads-state breadcrumb files
#
# Checks that BEADS breadcrumb files have valid lifecycle events.
# These are created by beads-lifecycle.sh during ap_exec.
#
# Usage:
#   bash test/contract/validate-beads-state.sh path/to/.beads-state

set -uo pipefail

FILE="${1:-}"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: validate-beads-state.sh <path/to/.beads-state>"
  exit 1
fi

VIOLATIONS=0
WARNINGS=0

violation() {
  echo "  FAIL: $1"
  ((VIOLATIONS++))
}

warning() {
  echo "  WARN: $1"
  ((WARNINGS++))
}

echo "Validating: $FILE"
echo ""

# Valid breadcrumb actions
VALID_ACTIONS="EPIC_START|EPIC_CREATED|EPIC_FOUND|TASK_CREATE|TASK_UPDATE|EPIC_CLOSE|ERROR"

LINE_NUM=0
HAS_START=false
HAS_CLOSE=false

while IFS= read -r line; do
  ((LINE_NUM++))
  [[ -z "$line" ]] && continue

  # Each line should be ACTION=TIMESTAMP DETAIL
  if echo "$line" | grep -qE "^(${VALID_ACTIONS})="; then
    ACTION=$(echo "$line" | cut -d= -f1)
    [[ "$ACTION" == "EPIC_START" ]] && HAS_START=true
    [[ "$ACTION" == "EPIC_CLOSE" ]] && HAS_CLOSE=true
  else
    violation "Line ${LINE_NUM}: Invalid breadcrumb format: $line"
  fi
done < "$FILE"

if [[ "$LINE_NUM" -eq 0 ]]; then
  violation "Empty .beads-state file"
else
  echo "  INFO: ${LINE_NUM} breadcrumb entries"
fi

if [[ "$HAS_START" == true ]]; then
  echo "  PASS: Epic lifecycle started"
else
  warning "No EPIC_START breadcrumb (BEADS may have been disabled)"
fi

# Close is optional — only present after orchestrator APPROVE/BLOCK
if [[ "$HAS_CLOSE" == true ]]; then
  echo "  INFO: Epic was closed (terminal decision reached)"
fi

# Check for ERROR breadcrumbs
ERROR_COUNT=$(grep -c "^ERROR=" "$FILE" 2>/dev/null || true)
ERROR_COUNT="${ERROR_COUNT:-0}"
if [[ "$ERROR_COUNT" -gt 0 ]]; then
  warning "${ERROR_COUNT} error breadcrumbs found (BEADS had issues but didn't block workflow)"
fi

# --- Report ---
echo ""
echo "Results: ${VIOLATIONS} violations, ${WARNINGS} warnings"

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "VERDICT: FAIL"
  exit 1
else
  if [[ "$WARNINGS" -gt 0 ]]; then
    echo "VERDICT: PASS (with warnings)"
  else
    echo "VERDICT: PASS"
  fi
  exit 0
fi
