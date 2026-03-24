#!/usr/bin/env bash
# validate-knowledge-entry.sh — Contract validator for knowledge JSONL files
#
# Checks that each line in a .jsonl knowledge file has required fields
# and valid values.
#
# Usage:
#   bash test/contract/validate-knowledge-entry.sh path/to/patterns.jsonl

set -uo pipefail

FILE="${1:-}"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: validate-knowledge-entry.sh <path/to/file.jsonl>"
  exit 1
fi

VIOLATIONS=0
WARNINGS=0
LINE_NUM=0
VALID=0

violation() {
  echo "  FAIL [line $LINE_NUM]: $1"
  ((VIOLATIONS++))
}

warning() {
  echo "  WARN [line $LINE_NUM]: $1"
  ((WARNINGS++))
}

echo "Validating: $FILE"
echo ""

# Determine expected type from filename
BASENAME=$(basename "$FILE" .jsonl)
VALID_TYPES=""
case "$BASENAME" in
  patterns)      VALID_TYPES="pattern" ;;
  gotchas)       VALID_TYPES="gotcha" ;;
  decisions)     VALID_TYPES="decision" ;;
  anti-patterns) VALID_TYPES="anti-pattern" ;;
  *)             VALID_TYPES="pattern|gotcha|decision|anti-pattern" ;;
esac

while IFS= read -r line; do
  ((LINE_NUM++))

  # Skip empty lines
  [[ -z "$line" ]] && continue

  # Validate JSON
  if ! echo "$line" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
    violation "Invalid JSON"
    continue
  fi

  # Check required fields
  RESULT=$(echo "$line" | python3 -c "
import json, sys
entry = json.loads(sys.stdin.read())
errors = []
warnings = []

# Required fields
for field in ['scope', 'content']:
    if field not in entry:
        errors.append(f'missing required field: {field}')

# Type field (recommended)
if 'type' not in entry:
    warnings.append('missing type field')
else:
    valid = '${VALID_TYPES}'.split('|')
    if entry['type'] not in valid:
        errors.append(f'invalid type \"{entry[\"type\"]}\" (expected: {valid})')

# Content should be non-empty
if 'content' in entry and not entry['content'].strip():
    errors.append('content is empty')

# Scope should be non-empty
if 'scope' in entry and not str(entry['scope']).strip():
    errors.append('scope is empty')

# Date field (recommended)
if 'date' not in entry and 'added' not in entry:
    warnings.append('no date/added field')

print('ERRORS:' + '|'.join(errors))
print('WARNINGS:' + '|'.join(warnings))
" 2>/dev/null)

  ERRORS=$(echo "$RESULT" | grep "^ERRORS:" | sed 's/^ERRORS://')
  WARNS=$(echo "$RESULT" | grep "^WARNINGS:" | sed 's/^WARNINGS://')

  if [[ -n "$ERRORS" ]]; then
    IFS='|' read -ra ERR_ARR <<< "$ERRORS"
    for err in "${ERR_ARR[@]}"; do
      [[ -n "$err" ]] && violation "$err"
    done
  fi

  if [[ -n "$WARNS" ]]; then
    IFS='|' read -ra WARN_ARR <<< "$WARNS"
    for w in "${WARN_ARR[@]}"; do
      [[ -n "$w" ]] && warning "$w"
    done
  fi

  ((VALID++))
done < "$FILE"

echo ""
echo "  Entries: ${LINE_NUM} total, ${VALID} valid JSON"
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
